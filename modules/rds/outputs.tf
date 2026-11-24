output "db_instance_id" {
  description = "RDS PostgreSQL instance identifier."
  value       = aws_db_instance.postgres.identifier
}

output "db_resource_id" {
  description = "RDS DbiResourceId used to scope IAM database authentication policies."
  value       = aws_db_instance.postgres.resource_id
}

output "db_endpoint" {
  description = "PostgreSQL connection endpoint (host:port)."
  value       = aws_db_instance.postgres.endpoint
}

output "db_address" {
  description = "PostgreSQL hostname."
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "PostgreSQL listening port."
  value       = aws_db_instance.postgres.port
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN when manage_master_user_password is enabled, else null."
  value       = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
}
