variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
}

variable "alarm_email" {
  description = "Optional email address subscribed to the SNS alerts topic (leave empty to skip)."
  type        = string
  default     = ""
}
