mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDAMOCKUSERID"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "random" {}

run "prod_ha_composition" {
  command = plan

  assert {
    condition     = length(output.nat_gateway_public_ips) == 2
    error_message = "Production composition must expose two NAT Gateway IPs for Multi-AZ egress HA."
  }

  assert {
    condition     = output.vpc_flow_log_group_name == "/aws/vpc/aws-prod-infra-prod-flow-logs"
    error_message = "Production composition must enable the VPC Flow Logs group."
  }

  assert {
    condition     = output.app_bucket_name == "aws-prod-infra-prod-assets-123456789012"
    error_message = "Production assets bucket must incorporate environment prefix and account ID."
  }

  assert {
    condition     = length(aws_cloudwatch_dashboard.ops) == 1 && output.dashboard_name == "aws-prod-infra-prod-ops"
    error_message = "Production composition must create the CloudWatch ops dashboard by default."
  }
}

run "prod_dashboard_toggle" {
  command = plan

  variables {
    enable_dashboard = false
  }

  assert {
    condition     = length(aws_cloudwatch_dashboard.ops) == 0 && output.dashboard_name == null
    error_message = "Setting enable_dashboard=false must suppress CloudWatch ops dashboard creation."
  }
}
