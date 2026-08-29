variable "project_name" {
  description = "Project/service name used in resource naming and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment, e.g. dev"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "Primary AZ: hosts the private/protected subnet, NAT gateway, and all EC2 instances"
  type        = string
}

variable "secondary_availability_zone" {
  description = <<-EOT
    Second AZ, used only for a second *public* subnet. AWS requires an ALB's
    subnets to span at least two Availability Zones even in an otherwise
    single-AZ topology — this subnet carries no NAT gateway and no compute,
    so it adds no meaningful cost, it exists purely to satisfy that ALB
    constraint.
  EOT
  type        = string
}
