output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state."
  value       = aws_s3_bucket.tf_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket storing Terraform state."
  value       = aws_s3_bucket.tf_state.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the account-wide GitHub Actions OIDC provider when created, else null."
  value       = var.create_github_oidc_provider && var.local_endpoint == "" ? aws_iam_openid_connect_provider.github[0].arn : null
}
