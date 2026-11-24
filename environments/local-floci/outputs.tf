output "vpc_id" {
  description = "Provisioned VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Provisioned public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Provisioned private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "app_instance_id" {
  description = "EC2 instance ID."
  value       = module.compute.instance_id
}

output "app_bucket_name" {
  description = "Application assets S3 bucket."
  value       = module.compute.app_bucket_name
}

output "log_group_name" {
  description = "CloudWatch Log Group name."
  value       = module.compute.log_group_name
}

output "ec2_role_name" {
  description = "EC2 IAM role name."
  value       = module.iam.ec2_role_name
}

output "db_instance_id" {
  description = "RDS PostgreSQL identifier."
  value       = module.rds.db_instance_id
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = module.rds.db_endpoint
}

output "alerts_topic_arn" {
  description = "SNS alerts topic ARN."
  value       = module.alerts.topic_arn
}
