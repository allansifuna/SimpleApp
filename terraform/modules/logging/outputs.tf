output "nginx_log_group_name" {
  value = aws_cloudwatch_log_group.nginx.name
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "log_group_arns" {
  value = [aws_cloudwatch_log_group.nginx.arn, aws_cloudwatch_log_group.app.arn]
}
