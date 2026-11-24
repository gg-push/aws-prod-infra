variable "aws_region" {
  description = "AWS region for the Terraform remote state bucket."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project tag applied to bootstrap resources."
  type        = string
  default     = "aws-prod-infra"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
}

variable "force_destroy" {
  description = "Allow destroying a non-empty state bucket (keep false in production)."
  type        = bool
  default     = false
}

variable "local_endpoint" {
  description = "Optional local Floci endpoint URL (e.g. http://localhost:4566). Leave empty for real AWS."
  type        = string
  default     = ""
}

variable "create_github_oidc_provider" {
  description = "Create the account-wide GitHub Actions OIDC identity provider (skipped when local_endpoint is set)."
  type        = bool
  default     = true
}

variable "enable_tls_bucket_policy" {
  description = "Attach an S3 bucket policy denying non-TLS (aws:SecureTransport = false) requests."
  type        = bool
  default     = true
}
