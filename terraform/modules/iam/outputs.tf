output "ec2_role_arn" {
  value = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2.name
}

output "gh_plan_role_arn" {
  value = aws_iam_role.gh_plan.arn
}

output "gh_apply_role_arn" {
  value = aws_iam_role.gh_apply.arn
}
