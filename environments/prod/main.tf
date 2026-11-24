data "aws_caller_identity" "current" {}

locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  app_bucket_name = "${local.name_prefix}-assets-${data.aws_caller_identity.current.account_id}"
  log_group_name  = "/aws/ec2/${local.name_prefix}"
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  availability_zones      = var.availability_zones
  enable_nat_gateway      = true
  single_nat_gateway      = var.single_nat_gateway
  enable_alb              = true
  enable_flow_logs        = true
  map_public_ip_on_launch = false
  allowed_ingress_cidrs   = var.allowed_ingress_cidrs
}

module "iam" {
  source = "../../modules/iam"

  name_prefix               = local.name_prefix
  aws_region                = var.aws_region
  account_id                = data.aws_caller_identity.current.account_id
  app_bucket_name           = local.app_bucket_name
  log_group_name            = local.log_group_name
  attach_managed_ssm_policy = true
  enable_github_oidc        = var.enable_github_oidc
  github_repo               = var.github_repo
  github_oidc_subjects      = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : ["repo:${var.github_repo}:environment:prod"]
  state_bucket_name         = var.state_bucket_name
}

module "alerts" {
  source = "../../modules/alerts"

  name_prefix           = local.name_prefix
  account_id            = data.aws_caller_identity.current.account_id
  enable_kms_encryption = true
  alarm_email           = var.alarm_email
}

module "alb" {
  source = "../../modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  alb_security_group_id      = module.vpc.alb_security_group_id
  acm_certificate_arn        = var.acm_certificate_arn
  enable_deletion_protection = true
  enable_cloudwatch_alarms   = true
  alarm_actions              = [module.alerts.topic_arn]
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                     = local.name_prefix
  private_subnet_ids              = module.vpc.private_subnet_ids
  db_security_group_id            = module.vpc.db_security_group_id
  engine_version                  = var.db_engine_version
  instance_class                  = var.db_instance_class
  allocated_storage               = 20
  max_allocated_storage           = 100
  db_name                         = var.db_name
  db_username                     = var.db_username
  manage_master_user_password     = var.manage_master_user_password
  db_password                     = var.db_password
  multi_az                        = true
  backup_retention_period         = 7
  deletion_protection             = true
  skip_final_snapshot             = false
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  enable_cloudwatch_alarms        = true
  alarm_actions                   = [module.alerts.topic_arn]
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                   = local.name_prefix
  environment                   = var.environment
  instance_type                 = var.instance_type
  enable_asg                    = true
  subnet_ids                    = module.vpc.private_subnet_ids
  target_group_arns             = [module.alb.target_group_arn]
  asg_min_size                  = var.asg_min_size
  asg_desired_capacity          = var.asg_desired_capacity
  asg_max_size                  = var.asg_max_size
  associate_public_ip           = false
  app_security_group_id         = module.vpc.app_security_group_id
  iam_instance_profile_name     = module.iam.ec2_instance_profile_name
  app_bucket_name               = local.app_bucket_name
  force_destroy_bucket          = false
  enable_s3_public_access_block = true
  log_group_name                = local.log_group_name
  log_retention_days            = 30
  enable_detailed_monitoring    = true
  enable_cloudwatch_alarms      = true
  alarm_actions                 = [module.alerts.topic_arn]
  db_endpoint                   = module.rds.db_endpoint
}
