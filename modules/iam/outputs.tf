output "ec2_role_arn" {
  description = "ARN of the EC2 application IAM role."
  value       = aws_iam_role.ec2.arn
}

output "ec2_role_name" {
  description = "Name of the EC2 application IAM role."
  value       = aws_iam_role.ec2.name
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile."
  value       = aws_iam_instance_profile.ec2.name
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions OIDC deploy role when enabled, else null."
  value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].arn : null
}
