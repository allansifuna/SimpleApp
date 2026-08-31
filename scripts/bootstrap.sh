#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_ACCOUNT:?set GITHUB_ACCOUNT to your GitHub username/org}"
: "${GITHUB_REPO:?set GITHUB_REPO to the repo name}"

PROJECT=rewards
ENVIRONMENT=dev
REGION=eu-west-2
STATE_BUCKET=rewards-tfstate
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EC2_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT}-${ENVIRONMENT}-ec2-role"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Creating the Terraform state bucket..."
aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" \
  || echo "Bucket already exists, continuing"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Fetching the GitHub OIDC root CA thumbprint..."
openssl s_client -servername token.actions.githubusercontent.com -showcerts \
  -connect token.actions.githubusercontent.com:443 </dev/null 2>/dev/null \
  | awk -v dir="$TMPDIR" 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++} {print > (dir "/cert" n ".pem")}'
LAST=$(ls "$TMPDIR"/cert*.pem | sort -V | tail -1)
THUMBPRINT=$(openssl x509 -in "$LAST" -fingerprint -sha1 -noout | sed 's/.*=//; s/://g' | tr 'A-Z' 'a-z')
echo "Thumbprint: $THUMBPRINT"

echo "Creating the OIDC provider..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list "$THUMBPRINT" \
  || echo "Provider already exists, continuing"

cat > "$TMPDIR/gh-plan-trust.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike": {"token.actions.githubusercontent.com:sub": "repo:${GITHUB_ACCOUNT}@*/${GITHUB_REPO}@*:environment:dev-plan"}
    }
  }]
}
EOF

cat > "$TMPDIR/gh-apply-trust.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike": {"token.actions.githubusercontent.com:sub": "repo:${GITHUB_ACCOUNT}@*/${GITHUB_REPO}@*:environment:dev-apply"}
    }
  }]
}
EOF

echo "Creating gh-plan..."
aws iam create-role --role-name "${PROJECT}-${ENVIRONMENT}-gh-plan" \
  --assume-role-policy-document "file://$TMPDIR/gh-plan-trust.json"
aws iam attach-role-policy --role-name "${PROJECT}-${ENVIRONMENT}-gh-plan" \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

cat > "$TMPDIR/gh-plan-state-lock.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "StateLockOnly",
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:DeleteObject"],
    "Resource": "arn:aws:s3:::${STATE_BUCKET}/${ENVIRONMENT}/terraform.tfstate.tflock"
  }]
}
EOF
aws iam put-role-policy --role-name "${PROJECT}-${ENVIRONMENT}-gh-plan" \
  --policy-name state-lock --policy-document "file://$TMPDIR/gh-plan-state-lock.json"

echo "Creating gh-apply..."
aws iam create-role --role-name "${PROJECT}-${ENVIRONMENT}-gh-apply" \
  --assume-role-policy-document "file://$TMPDIR/gh-apply-trust.json"
aws iam attach-role-policy --role-name "${PROJECT}-${ENVIRONMENT}-gh-apply" \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

cat > "$TMPDIR/gh-apply-iam-scoped.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageProjectScopedIamResources",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole",
        "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
        "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
        "iam:ListRoleTags", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
        "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
        "iam:GetInstanceProfile", "iam:TagInstanceProfile",
        "iam:ListInstanceProfilesForRole"
      ],
      "Resource": [
        "arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT}-${ENVIRONMENT}-*",
        "arn:aws:iam::${ACCOUNT_ID}:instance-profile/${PROJECT}-${ENVIRONMENT}-*"
      ]
    },
    {
      "Sid": "PassEc2Role",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "${EC2_ROLE_ARN}",
      "Condition": {"StringEquals": {"iam:PassedToService": "ec2.amazonaws.com"}}
    }
  ]
}
EOF
aws iam put-role-policy --role-name "${PROJECT}-${ENVIRONMENT}-gh-apply" \
  --policy-name iam-scoped --policy-document "file://$TMPDIR/gh-apply-iam-scoped.json"

cat > "$TMPDIR/gh-apply-deploy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescribeForInventory",
      "Effect": "Allow",
      "Action": ["ec2:DescribeInstances", "ec2:DescribeTags"],
      "Resource": "*"
    },
    {
      "Sid": "SsmTunnelForAnsibleSsh",
      "Effect": "Allow",
      "Action": ["ssm:StartSession", "ssm:TerminateSession", "ssm:ResumeSession"],
      "Resource": "*"
    }
  ]
}
EOF
aws iam put-role-policy --role-name "${PROJECT}-${ENVIRONMENT}-gh-apply" \
  --policy-name deploy --policy-document "file://$TMPDIR/gh-apply-deploy.json"

echo
echo "Done. Set these as the AWS_ROLE_ARN variable on the matching GitHub Environment:"
echo "  dev-plan:  arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT}-${ENVIRONMENT}-gh-plan"
echo "  dev-apply: arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT}-${ENVIRONMENT}-gh-apply"
