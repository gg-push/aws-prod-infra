variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
}

variable "account_id" {
  description = "Optional AWS account ID override (used for local Floci). Empty triggers sts:GetCallerIdentity."
  type        = string
  default     = ""
}

variable "enable_kms_encryption" {
  description = "Create a customer-managed KMS key permitting CloudWatch Alarms to publish encrypted SNS alerts."
  type        = bool
  default     = true
}

variable "enable_topic_policy" {
  description = "Attach an SNS topic policy scoping CloudWatch publish permissions to this account."
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Optional email address subscribed to the SNS alerts topic (leave empty to skip)."
  type        = string
  default     = ""
}
