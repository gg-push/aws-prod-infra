output "topic_arn" {
  description = "ARN of the encrypted SNS alerts topic."
  value       = aws_sns_topic.alerts.arn
}

output "topic_name" {
  description = "Name of the SNS alerts topic."
  value       = aws_sns_topic.alerts.name
}

output "kms_key_arn" {
  description = "Customer-managed KMS key ARN used to encrypt SNS alerts when enabled, else null."
  value       = var.enable_kms_encryption ? aws_kms_key.sns[0].arn : null
}
