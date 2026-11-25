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
  name_prefix     = "test-iam"
  aws_region      = "us-east-1"
  app_bucket_name = "test-iam-assets"
  log_group_name  = "/aws/ec2/test-iam"
}

run "iam_prod_oidc_and_rds_auth" {
  command = plan

  variables {
    enable_github_oidc       = true
    enable_rds_secret_access = true
    db_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds-test"
    enable_rds_iam_auth      = true
    db_resource_id           = "db-ABCDEF123456"
    state_bucket_name        = "test-tfstate-bucket"
    github_oidc_subjects     = ["repo:owner/repo:environment:prod"]
  }

  assert {
    condition     = length(aws_iam_role.github_actions) == 1 && length(aws_iam_openid_connect_provider.github) == 0 && length(aws_iam_role_policy_attachment.ssm_core) == 1
    error_message = "Prod IAM must create OIDC deploy role (without duplicating bootstrap OIDC provider) and attach SSM core policy."
  }

  assert {
    condition = (
      contains([for s in data.aws_iam_policy_document.ec2_app.statement : s.sid], "ScopedRDSSecretRead") &&
      contains([for s in data.aws_iam_policy_document.ec2_app.statement : s.sid], "ScopedRDSIAMConnect")
    )
    error_message = "EC2 app policy must include scoped RDS Secrets Manager and IAM auth statements when enabled."
  }

  assert {
    condition = (
      one([for c in data.aws_iam_policy_document.github_oidc_assume[0].statement[0].condition : c if c.variable == "token.actions.githubusercontent.com:sub"]).test == "StringEquals" &&
      tolist(one([for c in data.aws_iam_policy_document.github_oidc_assume[0].statement[0].condition : c if c.variable == "token.actions.githubusercontent.com:sub"]).values) == tolist(["repo:owner/repo:environment:prod"])
    )
    error_message = "OIDC trust policy must constrain sub via StringEquals to the configured subject."
  }

  assert {
    condition = (
      contains(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedAppBucketManage"]).actions, "s3:ListBucketVersions") &&
      contains(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedAppBucketManage"]).actions, "s3:DeleteObjectVersion")
    )
    error_message = "ScopedAppBucketManage must include s3:ListBucketVersions and s3:DeleteObjectVersion for versioned bucket teardown."
  }

  assert {
    condition = (
      !contains(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedIAMManage"]).resources, "arn:aws:iam::123456789012:role/test-iam-*") &&
      !contains(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedIAMManage"]).resources, "arn:aws:iam::123456789012:policy/test-iam-*") &&
      !contains(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedIAMManage"]).resources, "arn:aws:iam::123456789012:role/test-iam-github-oidc-role") &&
      !contains(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedIAMManage"]).resources, "arn:aws:iam::123456789012:policy/test-iam-github-oidc-policy")
    )
    error_message = "ScopedIAMManage must not allow wildcard prefix writes or self-modification of the GitHub OIDC deploy role/policy."
  }

  assert {
    condition = (
      tolist(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedIAMAttachPolicy"]).resources) == tolist(["arn:aws:iam::123456789012:role/test-iam-ec2-role"]) &&
      !contains(one([for c in one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedIAMAttachPolicy"]).condition : c if c.variable == "iam:PolicyARN"]).values, "arn:aws:iam::123456789012:policy/test-iam-*") &&
      tolist(one([for s in data.aws_iam_policy_document.github_actions_deploy[0].statement : s if s.sid == "ScopedFlowLogsInlinePolicyManage"]).resources) == tolist(["arn:aws:iam::123456789012:role/test-iam-vpc-flow-logs-role"])
    )
    error_message = "AttachRolePolicy must target only ec2-role and inline role policy writes must target only vpc-flow-logs-role."
  }
}

run "iam_local_floci_minimal" {
  command = plan

  variables {
    enable_github_oidc        = false
    attach_managed_ssm_policy = false
    enable_rds_secret_access  = false
    enable_rds_iam_auth       = false
  }

  assert {
    condition     = length(aws_iam_role.github_actions) == 0 && output.github_actions_role_arn == null && length(aws_iam_role_policy_attachment.ssm_core) == 0
    error_message = "Minimal Floci IAM must omit OIDC role and optional SSM attachment when disabled."
  }

  assert {
    condition = (
      !contains([for s in data.aws_iam_policy_document.ec2_app.statement : s.sid], "ScopedRDSSecretRead") &&
      !contains([for s in data.aws_iam_policy_document.ec2_app.statement : s.sid], "ScopedRDSIAMConnect")
    )
    error_message = "EC2 app policy must omit RDS secret and IAM auth statements when disabled."
  }
}
