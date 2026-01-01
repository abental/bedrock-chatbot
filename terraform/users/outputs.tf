output "application_user_name" {
  description = "Name of the application IAM user"
  value       = aws_iam_user.application.name
}

output "application_user_arn" {
  description = "ARN of the application IAM user"
  value       = aws_iam_user.application.arn
}

output "application_group_name" {
  description = "Name of the application-group IAM group"
  value       = aws_iam_group.application_group.name
}

output "application_group_arn" {
  description = "ARN of the application-group IAM group"
  value       = aws_iam_group.application_group.arn
}





