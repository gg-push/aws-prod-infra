variable "aws_region" {
  description = "AWS region for production deployment."
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
  default     = "prod"
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
  description = "Exact OIDC sub claims allowed to assume the prod deploy role."
  type        = list(string)
  default     = []
}

variable "state_bucket_name" {
  description = "Terraform remote state S3 bucket name to scope CI/CD permissions."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the production VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones for Multi-AZ high availability."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ingress_cidrs" {
  description = "Allowed CIDRs for public ALB HTTP/HTTPS ingress (app-sg remains restricted to alb-sg)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway instead of one per AZ (false = full Multi-AZ egress HA)."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN to terminate TLS 1.3 on port 443 and redirect HTTP:80."
  type        = string
  default     = ""
}

variable "alarm_email" {
  description = "Optional email address subscribed to production CloudWatch SNS alerts."
  type        = string
  default     = ""
}

variable "enable_dashboard" {
  description = "Create a CloudWatch operational dashboard combining ALB, ASG, and RDS metrics."
  type        = bool
  default     = true
}

variable "asg_min_size" {
  description = "Minimum instance count for the production Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired instance count for the production Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum instance count for the production Auto Scaling Group."
  type        = number
  default     = 4
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version (major version lets AWS select latest minor)."
  type        = string
  default     = "16"
}

variable "manage_master_user_password" {
  description = "Let AWS RDS manage and rotate the master password in Secrets Manager."
  type        = bool
  default     = true
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
