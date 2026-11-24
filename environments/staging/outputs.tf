output "vpc_id" {
  description = "Staging VPC ID."
  value       = module.vpc.vpc_id
}

output "app_public_ip" {
  description = "Public IPv4 of the staging EC2 instance."
  value       = module.compute.instance_public_ip
}

output "app_bucket_name" {
  description = "Staging S3 assets bucket."
  value       = module.compute.app_bucket_name
}

output "db_endpoint" {
  description = "Private RDS PostgreSQL endpoint."
  value       = module.rds.db_endpoint
}

output "github_actions_role_arn" {
  description = "OIDC IAM role ARN for GitHub Actions."
  value       = module.iam.github_actions_role_arn
}

output "alerts_topic_arn" {
  description = "SNS alerts topic ARN for CloudWatch alarms."
  value       = module.alerts.topic_arn
}
