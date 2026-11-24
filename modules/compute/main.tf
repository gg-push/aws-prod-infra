data "aws_ami" "al2023" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_s3_bucket" "assets" {
  bucket        = var.app_bucket_name
  force_destroy = var.force_destroy_bucket
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  count = var.enable_s3_public_access_block ? 1 : 0

  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "assets_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "assets_tls_only" {
  count = var.enable_s3_tls_policy ? 1 : 0

  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "expire-noncurrent-assets"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.assets]
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id
  user_data_rendered = templatefile("${path.module}/user_data.sh.tftpl", {
    environment             = var.environment
    name_prefix             = var.name_prefix
    db_endpoint             = var.db_endpoint
    log_group_name          = var.log_group_name
    enable_cloudwatch_agent = var.enable_cloudwatch_agent ? "true" : "false"
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
}

resource "aws_instance" "app" {
  count = var.enable_asg ? 0 : 1

  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.app_security_group_id]
  iam_instance_profile        = var.iam_instance_profile_name
  associate_public_ip_address = var.associate_public_ip
  monitoring                  = var.enable_detailed_monitoring
  user_data_replace_on_change = true
  user_data                   = local.user_data_rendered

  # Security hardening: enforce IMDSv2 to mitigate SSRF metadata credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size
  }

  tags = {
    Name = "${var.name_prefix}-web"
  }

  # Intentional AMI upgrades should set var.ami_id explicitly or use terraform apply -replace.
  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition     = var.subnet_id != ""
      error_message = "subnet_id is required when enable_asg is false."
    }
  }
}

resource "aws_launch_template" "app" {
  count = var.enable_asg ? 1 : 0

  name_prefix            = "${var.name_prefix}-web-"
  image_id               = local.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_security_group_id]
  user_data              = base64encode(local.user_data_rendered)
  update_default_version = true

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-web"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.name_prefix}-web-root"
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [image_id]
  }
}

resource "aws_autoscaling_group" "app" {
  count = var.enable_asg ? 1 : 0

  name_prefix               = "${var.name_prefix}-asg-"
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  health_check_type         = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app[0].id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-web"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = length(var.subnet_ids) >= 2
      error_message = "Provide at least 2 subnet_ids across AZs when enable_asg is true."
    }
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  count = var.enable_asg ? 1 : 0

  name                   = "${var.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name_prefix}-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when compute CPU utilization exceeds 80% for 10 minutes"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = var.enable_asg ? {
    AutoScalingGroupName = aws_autoscaling_group.app[0].name
    } : {
    InstanceId = aws_instance.app[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "status_check_failed" {
  count = var.enable_cloudwatch_alarms && !var.enable_asg ? 1 : 0

  alarm_name          = "${var.name_prefix}-ec2-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers when EC2 instance status check fails for 2 minutes"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    InstanceId = aws_instance.app[0].id
  }
}
