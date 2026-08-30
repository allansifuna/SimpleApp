module "network" {
  source = "../../modules/network"

  project_name                = local.project_name
  environment                 = local.environment
  vpc_cidr_block              = local.vpc_cidr_block
  availability_zone           = local.availability_zone
  secondary_availability_zone = local.secondary_availability_zone
}

module "security" {
  source = "../../modules/security"

  project_name = local.project_name
  environment  = local.environment
  vpc_id       = module.network.vpc_id
  app_port     = local.app_port
}

module "logging" {
  source = "../../modules/logging"

  project_name      = local.project_name
  environment       = local.environment
  retention_in_days = local.log_retention_days
}

module "iam" {
  source = "../../modules/iam"

  project_name   = local.project_name
  environment    = local.environment
  log_group_arns = module.logging.log_group_arns
}

module "compute" {
  source = "../../modules/compute"

  project_name         = local.project_name
  environment          = local.environment
  subnet_id            = module.network.private_subnet_id
  security_group_id    = module.security.ec2_sg_id
  iam_instance_profile = module.iam.ec2_instance_profile_name
  instances            = var.instances
  ssh_public_key       = var.ssh_public_key
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_name      = local.project_name
  environment       = local.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  app_port          = local.app_port
  health_check_path = local.health_check_path
  instance_ids      = module.compute.instance_ids
}
