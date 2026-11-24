data "aws_caller_identity" "current" {
  count = var.account_id == "" ? 1 : 0
}

locals {
  account_id = var.account_id != "" ? var.account_id : data.aws_caller_identity.current[0].account_id
}

data "aws_iam_policy_document" "sns_kms" {
  count = var.enable_kms_encryption ? 1 : 0

  statement {
    sid       = "EnableAccountKeyAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarmsEncrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "sns" {
  count = var.enable_kms_encryption ? 1 : 0

  description             = "Customer-managed KMS key for ${var.name_prefix} CloudWatch-to-SNS alerts"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sns_kms[0].json

  tags = {
    Name = "${var.name_prefix}-alerts-kms"
  }
}

resource "aws_kms_alias" "sns" {
  count = var.enable_kms_encryption ? 1 : 0

  name          = "alias/${var.name_prefix}-alerts"
  target_key_id = aws_kms_key.sns[0].key_id
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name_prefix}-alerts"
  kms_master_key_id = var.enable_kms_encryption ? aws_kms_key.sns[0].arn : null

  tags = {
    Name = "${var.name_prefix}-alerts"
  }
}

data "aws_iam_policy_document" "sns_topic" {
  count = var.enable_topic_policy ? 1 : 0

  statement {
    sid       = "AllowAccountOwner"
    effect    = "Allow"
    actions   = ["sns:*"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarmsPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  count = var.enable_topic_policy ? 1 : 0

  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_topic[0].json
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
