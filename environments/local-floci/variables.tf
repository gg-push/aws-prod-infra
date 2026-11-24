variable "aws_region" {
  description = "AWS region emulated by Floci."
  type        = string
  default     = "us-east-1"
}

variable "floci_endpoint" {
  description = "Local Floci endpoint URL."
  type        = string
  default     = "http://localhost:4566"
}

variable "project_name" {
  description = "Project name prefix."
  type        = string
  default     = "aws-prod-infra"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "local-floci"
}

variable "vpc_cidr" {
  description = "CIDR block for the local VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones for Multi-AZ subnet layout."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ingress_cidrs" {
  description = "Allowed ingress CIDRs for HTTP/HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ami_id" {
  description = "Placeholder AMI ID accepted by Floci."
  type        = string
  default     = "ami-0c55b159cbfafe1f0"
}

variable "attach_managed_ssm_policy" {
  description = "Attach AWS managed AmazonSSMManagedInstanceCore policy."
  type        = bool
  default     = false
}

variable "enable_s3_public_access_block" {
  description = "Apply S3 public access block."
  type        = bool
  default     = true
}

variable "enable_s3_tls_policy" {
  description = "Attach S3 TLS-only bucket policy."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch CPU alarm."
  type        = bool
  default     = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "appadmin"
}

variable "db_password" {
  description = "PostgreSQL master password (set via TF_VAR_db_password)."
  type        = string
  sensitive   = true
}
