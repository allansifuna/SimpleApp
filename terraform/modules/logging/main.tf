# Centralized logs

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/${var.project_name}/${var.environment}/nginx"
  retention_in_days = var.retention_in_days

  tags = {
    Name = "${var.project_name}-${var.environment}-nginx-logs"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = var.retention_in_days

  tags = {
    Name = "${var.project_name}-${var.environment}-app-logs"
  }
}
