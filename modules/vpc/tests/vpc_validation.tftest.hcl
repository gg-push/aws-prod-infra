mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name_prefix = "test-vpc"
}

run "vpc_prod_ha_and_s3_endpoint" {
  command = plan

  variables {
    enable_nat_gateway = true
    single_nat_gateway = false
    enable_alb         = true
    enable_s3_endpoint = true
    enable_flow_logs   = true
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 2
    error_message = "Production VPC must deploy one NAT Gateway per AZ when single_nat_gateway is false."
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 1 && aws_vpc_endpoint.s3[0].vpc_endpoint_type == "Gateway"
    error_message = "VPC must attach a free S3 Gateway VPC endpoint to private route tables."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_http_from_alb[0].from_port == 80 && length(aws_vpc_security_group_ingress_rule.app_http) == 0 && aws_vpc_security_group_ingress_rule.db_postgres_from_app.from_port == 5432
    error_message = "3-tier SG chaining must restrict app-sg:80 to alb-sg and db-sg:5432 to app-sg."
  }

  assert {
    condition     = length(aws_flow_log.main) == 1
    error_message = "VPC Flow Logs must be enabled when enable_flow_logs is true."
  }
}

run "vpc_rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [
    var.vpc_cidr,
  ]
}

run "vpc_rejects_single_az" {
  command = plan

  variables {
    availability_zones = ["us-east-1a"]
  }

  expect_failures = [
    var.availability_zones,
  ]
}
