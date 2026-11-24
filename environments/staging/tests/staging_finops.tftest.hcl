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

run "staging_composition" {
  command = plan

  variables {
    db_password = "StagingTestPassword123!"
  }

  assert {
    condition     = output.app_bucket_name == "aws-prod-infra-staging-assets-123456789012"
    error_message = "Staging assets bucket must incorporate environment prefix and account ID."
  }
}

run "staging_custom_naming" {
  command = plan

  variables {
    project_name = "demo"
    environment  = "qa"
    db_password  = "StagingTestPassword123!"
  }

  assert {
    condition     = output.app_bucket_name == "demo-qa-assets-123456789012"
    error_message = "Staging composition must propagate project and environment naming overrides cleanly."
  }
}
