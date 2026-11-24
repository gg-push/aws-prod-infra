output "instance_id" {
  description = "Standalone EC2 instance ID when enable_asg is false, else null."
  value       = var.enable_asg ? null : aws_instance.app[0].id
}

output "instance_public_ip" {
  description = "Standalone EC2 instance public IPv4 address (if assigned), else null."
  value       = var.enable_asg ? null : aws_instance.app[0].public_ip
}

output "instance_private_ip" {
  description = "Standalone EC2 instance private IPv4 address when enable_asg is false, else null."
  value       = var.enable_asg ? null : aws_instance.app[0].private_ip
}

output "asg_name" {
  description = "Auto Scaling Group name when enable_asg is true, else null."
  value       = var.enable_asg ? aws_autoscaling_group.app[0].name : null
}

output "app_bucket_name" {
  description = "S3 bucket name for application assets."
  value       = aws_s3_bucket.assets.bucket
}

output "app_bucket_arn" {
  description = "ARN of the application assets S3 bucket."
  value       = aws_s3_bucket.assets.arn
}

output "log_group_name" {
  description = "CloudWatch Log Group name."
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "CloudWatch Log Group ARN."
  value       = aws_cloudwatch_log_group.app.arn
}
