terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
  }
}

provider "aws" {
  region = var.aws_region

  access_key                  = var.local_endpoint != "" ? "test" : null
  secret_key                  = var.local_endpoint != "" ? "test" : null
  skip_credentials_validation = var.local_endpoint != ""
  skip_metadata_api_check     = var.local_endpoint != ""
  skip_requesting_account_id  = var.local_endpoint != ""
  s3_use_path_style           = var.local_endpoint != ""

  endpoints {
    s3  = var.local_endpoint != "" ? var.local_endpoint : null
    iam = var.local_endpoint != "" ? var.local_endpoint : null
  }

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Layer     = "Bootstrap"
    }
  }
}
