variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
}

variable "aws_region" {
  description = "AWS region used in scoped CloudWatch Log Group IAM ARNs."
  type        = string
}

variable "account_id" {
  description = "Optional AWS account ID override (used for local Floci). Empty triggers sts:GetCallerIdentity."
  type        = string
  default     = ""
}

variable "app_bucket_name" {
  description = "S3 bucket name the EC2 application role may read/write."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name the EC2 application role may stream to."
  type        = string
}

variable "attach_managed_ssm_policy" {
  description = "Attach AmazonSSMManagedInstanceCore for SSH-free Session Manager access."
  type        = bool
  default     = true
}

variable "enable_github_oidc" {
  description = "Create GitHub Actions OIDC identity provider and deploy role (disable for local Floci)."
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format authorized to assume the OIDC role."
  type        = string
  default     = "gg-push/aws-prod-infra"
}

variable "create_github_oidc_provider" {
  description = "Opt-in to creating the account-wide GitHub OIDC provider in this module (false when managed in bootstrap/)."
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Optional explicit GitHub OIDC provider ARN. Empty uses the standard account ARN."
  type        = string
  default     = ""
}

variable "github_oidc_subjects" {
  description = "Exact OIDC sub claims allowed to assume the GitHub Actions role (defaults to refs/heads/main)."
  type        = list(string)
  default     = []
}

variable "state_bucket_name" {
  description = "Optional Terraform remote state S3 bucket name to scope CI/CD state access."
  type        = string
  default     = ""
}
