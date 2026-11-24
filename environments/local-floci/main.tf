locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  app_bucket_name = "${local.name_prefix}-assets-local"
  log_group_name  = "/aws/ec2/${local.name_prefix}"
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix             = local.name_prefix
  vpc_cidr                = var.vpc_cidr
  availability_zones      = var.availability_zones
  enable_nat_gateway      = false
  map_public_ip_on_launch = true
  allowed_ingress_cidrs   = var.allowed_ingress_cidrs
}

module "iam" {
  source = "../../modules/iam"

  name_prefix               = local.name_prefix
  aws_region                = var.aws_region
  account_id                = "000000000000"
  app_bucket_name           = local.app_bucket_name
  log_group_name            = local.log_group_name
  attach_managed_ssm_policy = var.attach_managed_ssm_policy
  enable_github_oidc        = false
}

module "rds" {
  source = "../../modules/rds"

  name_prefix             = local.name_prefix
  private_subnet_ids      = module.vpc.private_subnet_ids
  db_security_group_id    = module.vpc.db_security_group_id
  engine_version          = var.db_engine_version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  multi_az                = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                   = local.name_prefix
  environment                   = var.environment
  ami_id                        = var.ami_id
  instance_type                 = "t3.micro"
  subnet_id                     = module.vpc.public_subnet_ids[0]
  associate_public_ip           = true
  app_security_group_id         = module.vpc.app_security_group_id
  iam_instance_profile_name     = module.iam.ec2_instance_profile_name
  app_bucket_name               = local.app_bucket_name
  force_destroy_bucket          = true
  enable_s3_public_access_block = var.enable_s3_public_access_block
  enable_s3_tls_policy          = var.enable_s3_tls_policy
  log_group_name                = local.log_group_name
  log_retention_days            = 7
  enable_cloudwatch_alarms      = var.enable_cloudwatch_alarms
  enable_cloudwatch_agent       = false
  db_endpoint                   = module.rds.db_endpoint
}
