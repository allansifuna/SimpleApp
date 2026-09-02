# output "alb_dns_name" {
#   description = "Public entrypoint — curl this for the health JSON"
#   value       = module.loadbalancer.alb_dns_name
# }

# output "nginx_log_group_name" {
#   value = module.logging.nginx_log_group_name
# }

# output "app_log_group_name" {
#   value = module.logging.app_log_group_name
# }

# output "instance_ids" {
#   description = "Fed into app/ansible/inventory/hosts by the deploy workflow"
#   value       = module.compute.instance_ids
# }
