variable "name_prefix" {
  description = "Resource naming prefix (e.g. aws-prod-infra-staging)."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of two or more Availability Zones for Multi-AZ subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Provide at least two Availability Zones for Multi-AZ isolation."
  }
}

variable "enable_nat_gateway" {
  description = "Provision a NAT Gateway for private-subnet outbound internet (adds ~$32/mo)."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway (true) or one per AZ for Multi-AZ egress HA (false)."
  type        = bool
  default     = true
}

variable "enable_alb" {
  description = "Provision an ALB security group and restrict app-sg port 80 strictly to it."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "CloudWatch Log Group retention in days for VPC Flow Logs."
  type        = number
  default     = 30
}

variable "map_public_ip_on_launch" {
  description = "Assign public IPv4 addresses automatically to instances launched in public subnets."
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "Allowed CIDR blocks for inbound HTTP/HTTPS traffic."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_s3_endpoint" {
  description = "Create a free S3 Gateway VPC Endpoint on private route tables to bypass NAT Gateway data charges."
  type        = bool
  default     = false
}
