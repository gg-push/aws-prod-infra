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
  enable_nat_gateway      = false # FinOps: $0 idle NAT cost in staging/Free Tier
  map_public_ip_on_launch = true
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
  github_oidc_subjects      = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : ["repo:${var.github_repo}:ref:refs/heads/main", "repo:${var.github_repo}:environment:staging"]
  state_bucket_name         = var.state_bucket_name
}

module "alerts" {
  source = "../../modules/alerts"

  name_prefix = local.name_prefix
  alarm_email = var.alarm_email
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                     = local.name_prefix
  private_subnet_ids              = module.vpc.private_subnet_ids
  db_security_group_id            = module.vpc.db_security_group_id
  engine_version                  = var.db_engine_version
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  db_name                         = var.db_name
  db_username                     = var.db_username
  manage_master_user_password     = var.manage_master_user_password
  db_password                     = var.db_password
  multi_az                        = false
  backup_retention_period         = 1
  deletion_protection             = false
  skip_final_snapshot             = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  enable_cloudwatch_alarms        = true
  alarm_actions                   = [module.alerts.topic_arn]
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                   = local.name_prefix
  environment                   = var.environment
  instance_type                 = var.instance_type
  subnet_id                     = module.vpc.public_subnet_ids[0]
  associate_public_ip           = true
  app_security_group_id         = module.vpc.app_security_group_id
  iam_instance_profile_name     = module.iam.ec2_instance_profile_name
  app_bucket_name               = local.app_bucket_name
  force_destroy_bucket          = true
  enable_s3_public_access_block = true
  log_group_name                = local.log_group_name
  log_retention_days            = 14
  enable_cloudwatch_alarms      = true
  alarm_actions                 = [module.alerts.topic_arn]
  db_endpoint                   = module.rds.db_endpoint
}
