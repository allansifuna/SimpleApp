variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "log_group_arns" {
  description = "CloudWatch Log Group ARNs the app instances must write to"
  type        = list(string)
}
