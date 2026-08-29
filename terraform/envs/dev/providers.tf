terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  project_name                = "rewards"
  environment                 = "dev"
  owner                       = "allansifuna"
  cost_center                 = "payments"
  region                      = "eu-west-2"
  availability_zone           = "eu-west-2a"
  secondary_availability_zone = "eu-west-2b"
  vpc_cidr_block              = "10.0.0.0/16"
  app_port                    = 80
  health_check_path           = "/healthz"
  log_retention_days          = 14

  common_tags = {
    environment = local.environment
    service     = local.project_name
    owner       = local.owner
    cost_center = local.cost_center
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}
