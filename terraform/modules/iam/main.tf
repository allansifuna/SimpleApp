# EC2 instance role
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "ec2_inline" {
  statement {
    sid = "WriteAppLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = var.log_group_arns
  }
}

resource "aws_iam_role_policy" "ec2_inline" {
  name   = "${var.project_name}-${var.environment}-ec2-inline"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_inline.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# GitHub Actions OIDC
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[
      length(data.tls_certificate.github_actions.certificates) - 1
    ].sha1_fingerprint
  ]
}

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
}

data "aws_iam_policy_document" "gh_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_account}/${var.github_repo}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "gh_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_account}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

# Plan role
resource "aws_iam_role" "gh_plan" {
  name               = "${var.project_name}-${var.environment}-gh-plan"
  assume_role_policy = data.aws_iam_policy_document.gh_plan_trust.json
}

resource "aws_iam_role_policy_attachment" "gh_plan_readonly" {
  role       = aws_iam_role.gh_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Apply role
resource "aws_iam_role" "gh_apply" {
  name               = "${var.project_name}-${var.environment}-gh-apply"
  assume_role_policy = data.aws_iam_policy_document.gh_apply_trust.json
}

resource "aws_iam_role_policy_attachment" "gh_apply_poweruser" {
  role       = aws_iam_role.gh_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "gh_apply_iam_scoped" {
  statement {
    sid = "ManageProjectScopedIamResources"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole",
      "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:GetRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:GetInstanceProfile", "iam:TagInstanceProfile",
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
    ]
    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-*",
      "arn:aws:iam::*:instance-profile/${var.project_name}-${var.environment}-*",
      "arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com",
    ]
  }

  statement {
    sid       = "PassEc2Role"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ec2.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "gh_apply_iam_scoped" {
  name   = "${var.project_name}-${var.environment}-gh-apply-iam-scoped"
  role   = aws_iam_role.gh_apply.id
  policy = data.aws_iam_policy_document.gh_apply_iam_scoped.json
}

# For Ansible: inventory lookup + the SSM tunnel
data "aws_iam_policy_document" "gh_apply_deploy" {
  statement {
    sid       = "DescribeForInventory"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }

  statement {
    sid = "SsmTunnelForAnsibleSsh"
    actions = [
      "ssm:StartSession",
      "ssm:TerminateSession",
      "ssm:ResumeSession",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "gh_apply_deploy" {
  name   = "${var.project_name}-${var.environment}-gh-apply-deploy"
  role   = aws_iam_role.gh_apply.id
  policy = data.aws_iam_policy_document.gh_apply_deploy.json
}
