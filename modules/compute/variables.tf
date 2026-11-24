variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g. local-floci, staging, prod)."
  type        = string
}

variable "ami_id" {
  description = "Optional explicit AMI ID. Leave empty on AWS to query latest Amazon Linux 2023."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro / t2.micro for AWS Free Tier)."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID where a standalone EC2 instance is launched (when enable_asg is false)."
  type        = string
  default     = ""
}

variable "enable_asg" {
  description = "Provision a Multi-AZ Auto Scaling Group + Launch Template instead of a single EC2 instance."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of private subnet IDs across AZs for the Auto Scaling Group (when enable_asg is true)."
  type        = list(string)
  default     = []
}

variable "target_group_arns" {
  description = "Optional ALB target group ARNs to register ASG instances with."
  type        = list(string)
  default     = []
}

variable "asg_min_size" {
  description = "Minimum instance count for the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired instance count for the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum instance count for the Auto Scaling Group."
  type        = number
  default     = 4
}

variable "associate_public_ip" {
  description = "Associate a public IPv4 address (true in staging without NAT, false behind ALB/NAT)."
  type        = bool
  default     = true
}

variable "app_security_group_id" {
  description = "Security group ID attached to the EC2 instance."
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name attached to the EC2 instance."
  type        = string
}

variable "app_bucket_name" {
  description = "Globally unique S3 bucket name for application assets/backups."
  type        = string
}

variable "force_destroy_bucket" {
  description = "Allow Terraform to destroy a non-empty app assets bucket."
  type        = bool
  default     = false
}

variable "enable_s3_public_access_block" {
  description = "Apply S3 public access block configuration."
  type        = bool
  default     = true
}

variable "enable_s3_tls_policy" {
  description = "Attach an S3 bucket policy denying non-TLS (aws:SecureTransport = false) requests."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent S3 object versions expire."
  type        = number
  default     = 90
}

variable "log_group_name" {
  description = "CloudWatch Log Group name for application logs."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 14
}

variable "root_volume_size" {
  description = "Root EBS gp3 volume size in GiB."
  type        = number
  default     = 20
}

variable "enable_detailed_monitoring" {
  description = "Enable 1-minute CloudWatch detailed EC2 monitoring (paid feature on AWS)."
  type        = bool
  default     = false
}

variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch metric alarms for the compute tier."
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of SNS topic ARNs notified when compute alarms fire or recover."
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_agent" {
  description = "Install and start Amazon CloudWatch Agent to ship Nginx logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "db_endpoint" {
  description = "RDS PostgreSQL endpoint passed to application user_data."
  type        = string
  default     = "localhost:5432"
}
