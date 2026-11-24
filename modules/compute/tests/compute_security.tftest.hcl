mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name_prefix               = "test-compute"
  ami_id                    = "ami-0123456789abcdef0"
  app_security_group_id     = "sg-12345678"
  iam_instance_profile_name = "test-ec2-profile"
  app_bucket_name           = "test-assets-bucket"
  log_group_name            = "/aws/ec2/test-compute"
}

run "compute_prod_asg" {
  command = plan

  variables {
    environment = "prod"
    enable_asg  = true
    subnet_ids  = ["subnet-11111111", "subnet-22222222"]
  }

  assert {
    condition     = length(aws_autoscaling_group.app) == 1 && aws_autoscaling_group.app[0].min_size == 2 && aws_autoscaling_group.app[0].max_size == 4
    error_message = "Prod compute must provision an ASG sized 2-4 instances."
  }

  assert {
    condition     = aws_launch_template.app[0].metadata_options[0].http_tokens == "required" && tostring(aws_launch_template.app[0].block_device_mappings[0].ebs[0].encrypted) == "true" && aws_launch_template.app[0].block_device_mappings[0].ebs[0].volume_type == "gp3"
    error_message = "Launch template must enforce IMDSv2 and encrypted gp3 root storage."
  }
}

run "compute_staging_ec2" {
  command = plan

  variables {
    environment = "staging"
    enable_asg  = false
    subnet_id   = "subnet-11111111"
  }

  assert {
    condition     = length(aws_instance.app) == 1 && length(aws_autoscaling_group.app) == 0
    error_message = "Staging compute must launch a single EC2 instance without an ASG."
  }

  assert {
    condition     = aws_instance.app[0].metadata_options[0].http_tokens == "required" && aws_instance.app[0].root_block_device[0].encrypted == true
    error_message = "Standalone EC2 must enforce IMDSv2 and encrypted gp3 root storage."
  }
}
