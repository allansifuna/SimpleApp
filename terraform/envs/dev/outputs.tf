output "alb_dns_name" {
  description = "Public entrypoint — curl this for the health JSON"
  value       = module.loadbalancer.alb_dns_name
}

output "nginx_log_group_name" {
  value = module.logging.nginx_log_group_name
}

output "app_log_group_name" {
  value = module.logging.app_log_group_name
}

output "gh_plan_role_arn" {
  description = "Set as the AWS_ROLE_ARN GitHub Actions variable for the plan job"
  value       = module.iam.gh_plan_role_arn
}

output "gh_apply_role_arn" {
  description = "Set as the AWS_ROLE_ARN GitHub Actions variable for the apply/deploy job"
  value       = module.iam.gh_apply_role_arn
}

output "instance_ids" {
  description = "Fed into app/ansible/inventory/hosts by the deploy workflow"
  value       = module.compute.instance_ids
}
