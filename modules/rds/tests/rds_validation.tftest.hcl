mock_provider "aws" {}
mock_provider "random" {}

variables {
  name_prefix          = "test-rds"
  private_subnet_ids   = ["subnet-11111111", "subnet-22222222"]
  db_security_group_id = "sg-12345678"
}

run "rds_prod_hardened" {
  command = plan

  variables {
    multi_az                    = true
    deletion_protection         = true
    manage_master_user_password = true
    skip_final_snapshot         = false
  }

  assert {
    condition     = aws_db_instance.postgres.multi_az == true && aws_db_instance.postgres.storage_encrypted == true && aws_db_instance.postgres.publicly_accessible == false && aws_db_instance.postgres.deletion_protection == true && aws_db_instance.postgres.manage_master_user_password == true && aws_db_instance.postgres.iam_database_authentication_enabled == true
    error_message = "Production RDS must enforce Multi-AZ, encryption, private placement, deletion protection, Secrets Manager rotation, and IAM DB auth."
  }
}

run "rds_rejects_weak_password" {
  command = plan

  variables {
    manage_master_user_password = false
    db_password                 = "bad/pass"
  }

  expect_failures = [
    aws_db_instance.postgres,
  ]
}
