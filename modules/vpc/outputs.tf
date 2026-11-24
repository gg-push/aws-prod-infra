output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across Availability Zones."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs across Availability Zones."
  value       = aws_subnet.private[*].id
}

output "app_security_group_id" {
  description = "Security group ID attached to application EC2 instances."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group ID attached to RDS PostgreSQL."
  value       = aws_security_group.db.id
}

output "alb_security_group_id" {
  description = "Security group ID for the public ALB when enable_alb is true, else null."
  value       = var.enable_alb ? aws_security_group.alb[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the first NAT Gateway when enabled, else null."
  value       = try(aws_eip.nat[0].public_ip, null)
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs across AZs when enabled."
  value       = aws_eip.nat[*].public_ip
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs when enabled, else null."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : null
}

output "s3_endpoint_id" {
  description = "S3 Gateway VPC Endpoint ID when enabled, else null."
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}
