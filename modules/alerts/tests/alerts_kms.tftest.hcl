mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDAMOCKUSERID"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name_prefix = "test-alerts"
}

run "alerts_prod_kms" {
  command = plan

  variables {
    enable_kms_encryption = true
  }

  assert {
    condition     = length(aws_kms_key.sns) == 1 && aws_kms_key.sns[0].enable_key_rotation == true && length(aws_sns_topic_policy.alerts) == 1
    error_message = "Prod alerts must provision a rotated KMS CMK and scoped SNS topic policy."
  }
}

run "alerts_staging_finops" {
  command = plan

  variables {
    enable_kms_encryption = false
  }

  assert {
    condition     = length(aws_kms_key.sns) == 0 && length(aws_sns_topic_policy.alerts) == 1
    error_message = "Staging alerts must omit the paid KMS CMK while retaining the scoped SNS topic policy."
  }
}
