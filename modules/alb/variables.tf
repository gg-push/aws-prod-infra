variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the target group resides."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs across at least two Availability Zones."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID attached to the ALB."
  type        = string
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN to enable HTTPS:443 and redirect HTTP:80 to HTTPS."
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  description = "Protect the ALB against accidental deletion."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch alarms for ALB target 5XX errors and unhealthy targets."
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of SNS topic ARNs notified when ALB alarms fire or recover."
  type        = list(string)
  default     = []
}
