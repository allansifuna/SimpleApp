variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnets the ALB itself sits in (a list even though this topology has one)"
  type        = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/healthz"
}

variable "instance_ids" {
  description = "Map of app instance IDs to attach to the target group"
  type        = map(string)
}
