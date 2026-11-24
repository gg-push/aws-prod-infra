variable "aws_region" {
  description = "AWS region for staging deployment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix."
  type        = string
  default     = "aws-prod-infra"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "staging"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the OIDC deploy role."
  type        = string
  default     = "gg-push/aws-prod-infra"
}

variable "enable_github_oidc" {
  description = "Provision GitHub Actions OIDC deploy role (uses the account-wide OIDC provider from bootstrap/)."
  type        = bool
  default     = true
}

variable "github_oidc_subjects" {
  description = "Exact OIDC sub claims allowed to assume the staging deploy role."
  type        = list(string)
  default     = []
}

variable "state_bucket_name" {
  description = "Terraform remote state S3 bucket name to scope CI/CD permissions."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the staging VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones for Multi-AZ subnet isolation."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ingress_cidrs" {
  description = "Allowed CIDRs for HTTP/HTTPS ingress (restrict to your IP during tests)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version (major version lets AWS select latest minor)."
  type        = string
  default     = "16"
}

variable "manage_master_user_password" {
  description = "Let AWS RDS manage the master password in Secrets Manager."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master database username."
  type        = string
  default     = "appadmin"
}

variable "db_password" {
  description = "Master database password when manage_master_user_password is false (pass via TF_VAR_db_password)."
  type        = string
  default     = null
  sensitive   = true
}

variable "alarm_email" {
  description = "Optional email address subscribed to staging CloudWatch SNS alerts."
  type        = string
  default     = ""
}
