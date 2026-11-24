variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs spanning at least two AZs for the DB subnet group."
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID restricting PostgreSQL access to the app tier."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class (db.t3.micro / db.t4g.micro for Free Tier)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial RDS storage in GiB (Free Tier includes up to 20 GiB)."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper autoscaling limit in GiB (0 disables storage autoscaling)."
  type        = number
  default     = 0
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

variable "manage_master_user_password" {
  description = "Let AWS RDS manage and rotate the master password in Secrets Manager (recommended for prod)."
  type        = bool
  default     = false
}

variable "db_password" {
  description = "Master database password when manage_master_user_password is false (supply via TF_VAR_db_password; never hardcode)."
  type        = string
  default     = null
  sensitive   = true
}

variable "auto_minor_version_upgrade" {
  description = "Allow RDS to apply minor PostgreSQL engine upgrades during maintenance windows."
  type        = bool
  default     = true
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication on PostgreSQL."
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of PostgreSQL log types to export to CloudWatch Logs (e.g. postgresql, upgrade)."
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch CPU and free storage alarms for the RDS instance."
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "List of SNS topic ARNs notified when RDS alarms fire or recover."
  type        = list(string)
  default     = []
}

variable "multi_az" {
  description = "Enable synchronous Multi-AZ standby replica (true in prod, false in Free Tier staging)."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Automated backup retention window in days."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Protect the RDS instance against accidental deletion."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip creating a final snapshot on destroy (true for staging/local, false for prod)."
  type        = bool
  default     = true
}
