output "vpc_id" {
  description = "Production VPC ID."
  value       = module.vpc.vpc_id
}

output "nat_gateway_public_ips" {
  description = "Egress NAT Gateway public IPs across AZs."
  value       = module.vpc.nat_gateway_public_ips
}

output "alb_dns_name" {
  description = "Public DNS name of the production Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "asg_name" {
  description = "Production Auto Scaling Group name."
  value       = module.compute.asg_name
}

output "alerts_topic_arn" {
  description = "SNS alerts topic ARN for production CloudWatch alarms."
  value       = module.alerts.topic_arn
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs."
  value       = module.vpc.flow_log_group_name
}

output "app_bucket_name" {
  description = "Production S3 assets bucket."
  value       = module.compute.app_bucket_name
}

output "db_endpoint" {
  description = "Multi-AZ private RDS PostgreSQL endpoint."
  value       = module.rds.db_endpoint
}

output "db_master_user_secret_arn" {
  description = "Secrets Manager ARN for the RDS master password (when AWS-managed)."
  value       = module.rds.master_user_secret_arn
}

output "github_actions_role_arn" {
  description = "OIDC IAM role ARN for GitHub Actions."
  value       = module.iam.github_actions_role_arn
}
