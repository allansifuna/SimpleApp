variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "retention_in_days" {
  description = "CloudWatch Logs retention for both log groups"
  type        = number
  default     = 14
}
