output "instance_ids" {
  value = { for k, v in aws_instance.app : k => v.id }
}
