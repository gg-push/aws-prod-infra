data "aws_caller_identity" "current" {
  count = var.account_id == "" ? 1 : 0
}

locals {
  account_id = var.account_id != "" ? var.account_id : data.aws_caller_identity.current[0].account_id
  github_oidc_provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : (
    var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
  )
  github_oidc_subjects = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : ["repo:${var.github_repo}:ref:refs/heads/main"]
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

data "aws_iam_policy_document" "ec2_app" {
  statement {
    sid    = "ScopedAppBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.app_bucket_name}",
      "arn:aws:s3:::${var.app_bucket_name}/*",
    ]
  }

  statement {
    sid    = "ScopedCloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${var.log_group_name}:*",
    ]
  }

  statement {
    sid       = "ScopedCloudWatchDescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:*"]
  }

  dynamic "statement" {
    for_each = var.enable_rds_secret_access ? [1] : []

    content {
      sid       = "ScopedRDSSecretRead"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = [var.db_secret_arn]
    }
  }

  dynamic "statement" {
    for_each = var.enable_rds_iam_auth ? [1] : []

    content {
      sid       = "ScopedRDSIAMConnect"
      effect    = "Allow"
      actions   = ["rds-db:connect"]
      resources = ["arn:aws:rds-db:${var.aws_region}:${local.account_id}:dbuser:${var.db_resource_id}/${var.db_username}"]
    }
  }
}

resource "aws_iam_policy" "ec2_app" {
  name        = "${var.name_prefix}-ec2-app-policy"
  description = "Least-privilege S3 and CloudWatch Logs permissions for application EC2 instances"
  policy      = data.aws_iam_policy_document.ec2_app.json
}

resource "aws_iam_role_policy_attachment" "ec2_app" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app.arn
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.attach_managed_ssm_policy ? 1 : 0

  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# GitHub Actions OIDC federation (zero long-lived AWS access keys in CI/CD)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc && var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_policy_document" "github_oidc_assume" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count = var.enable_github_oidc ? 1 : 0

  name               = "${var.name_prefix}-github-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume[0].json
}

data "aws_iam_policy_document" "github_actions_deploy" {
  # checkov:skip=CKV_AWS_107:CI deploy role inspects IAM/RDS metadata; PassRole is strictly constrained by PassedToService and role name.
  # checkov:skip=CKV_AWS_108:CI deploy role reads S3 state and CloudWatch/EC2 state; PassRole and AttachRolePolicy are strictly constrained.
  # checkov:skip=CKV_AWS_109:CI deploy role manages repo-prefixed IAM roles/policies and PassRole/AttachRolePolicy strictly under constraints.
  # checkov:skip=CKV_AWS_111:Terraform CI requires EC2/ALB/ASG/KMS provisioning APIs alongside prefixed IAM/RDS/S3/CW statements.
  # checkov:skip=CKV_AWS_356:AWS EC2, ELB, AutoScaling, Describe*, and kms:CreateKey actions require "*" resource scope.
  count = var.enable_github_oidc ? 1 : 0

  statement {
    sid       = "ScopedPassRoleToEC2"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ec2.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "ScopedPassRoleToFlowLogs"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.name_prefix}-vpc-flow-logs-role"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["vpc-flow-logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "ScopedIAMRead"
    effect    = "Allow"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid    = "ScopedIAMManage"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole*",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-ec2-role",
      "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-vpc-flow-logs-role",
      "arn:aws:iam::${local.account_id}:policy/${var.name_prefix}-ec2-app-policy",
      "arn:aws:iam::${local.account_id}:instance-profile/${var.name_prefix}-ec2-profile",
    ]
  }

  statement {
    sid    = "ScopedFlowLogsInlinePolicyManage"
    effect = "Allow"
    actions = [
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-vpc-flow-logs-role",
    ]
  }

  statement {
    sid    = "ScopedIAMAttachPolicy"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-ec2-role",
    ]

    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::${local.account_id}:policy/${var.name_prefix}-ec2-app-policy",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
    }
  }

  statement {
    sid    = "ScopedAppBucketManage"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucket*",
      "s3:PutBucket*",
      "s3:DeleteBucketPolicy",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
    ]
    resources = [
      "arn:aws:s3:::${var.app_bucket_name}",
      "arn:aws:s3:::${var.app_bucket_name}/*",
    ]
  }

  dynamic "statement" {
    for_each = var.state_bucket_name != "" ? [1] : []

    content {
      sid    = "ScopedTerraformStateS3"
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = [
        "arn:aws:s3:::${var.state_bucket_name}",
        "arn:aws:s3:::${var.state_bucket_name}/*",
      ]
    }
  }

  statement {
    sid       = "ScopedCloudWatchRead"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups", "cloudwatch:DescribeAlarms"]
    resources = ["*"]
  }

  statement {
    sid    = "ScopedCloudWatchLogsManage"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${var.log_group_name}",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${var.log_group_name}:*",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/vpc/${var.name_prefix}-flow-logs",
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/vpc/${var.name_prefix}-flow-logs:*",
    ]
  }

  statement {
    sid    = "ScopedSNSManage"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:GetSubscriptionAttributes",
      "sns:ListTagsForResource",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = [
      "arn:aws:sns:${var.aws_region}:${local.account_id}:${var.name_prefix}-*",
    ]
  }

  statement {
    sid       = "ScopedALBAndASGManage"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:*", "autoscaling:*"]
    resources = ["*"]
  }

  statement {
    sid    = "ScopedCloudWatchAlarmsManage"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      "arn:aws:cloudwatch:${var.aws_region}:${local.account_id}:alarm:${var.name_prefix}-*",
    ]
  }

  statement {
    sid    = "ScopedCloudWatchDashboardManage"
    effect = "Allow"
    actions = [
      "cloudwatch:PutDashboard",
      "cloudwatch:GetDashboard",
      "cloudwatch:DeleteDashboards",
    ]
    resources = [
      "arn:aws:cloudwatch::${local.account_id}:dashboard/${var.name_prefix}-*",
    ]
  }

  statement {
    sid    = "ScopedKMSManage"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:EnableKeyRotation",
      "kms:GetKeyRotationStatus",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ListResourceTags",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:ListAliases",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ScopedRDSRead"
    effect    = "Allow"
    actions   = ["rds:Describe*", "rds:ListTagsForResource"]
    resources = ["*"]
  }

  statement {
    sid    = "ScopedRDSManage"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:CreateDBSnapshot",
      "rds:DeleteDBSnapshot",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
    ]
    resources = [
      "arn:aws:rds:${var.aws_region}:${local.account_id}:db:${var.name_prefix}-*",
      "arn:aws:rds:${var.aws_region}:${local.account_id}:subgrp:${var.name_prefix}-*",
      "arn:aws:rds:${var.aws_region}:${local.account_id}:snapshot:${var.name_prefix}-*",
    ]
  }

  statement {
    sid    = "EC2AndVPCManage"
    effect = "Allow"
    actions = [
      "ec2:*",
      "ssm:GetParameter*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions" {
  count = var.enable_github_oidc ? 1 : 0

  name        = "${var.name_prefix}-github-oidc-policy"
  description = "Scoped Terraform CI/CD execution policy for GitHub Actions OIDC role"
  policy      = data.aws_iam_policy_document.github_actions_deploy[0].json
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  count = var.enable_github_oidc ? 1 : 0

  role       = aws_iam_role.github_actions[0].name
  policy_arn = aws_iam_policy.github_actions[0].arn
}
