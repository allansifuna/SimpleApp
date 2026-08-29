variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  description = "Port Nginx listens on, on the app instances"
  type        = number
  default     = 80
}
