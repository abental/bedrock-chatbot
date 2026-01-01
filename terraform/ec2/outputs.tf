output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.flask_app.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.flask_app.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.flask_app.public_dns
}

output "security_group_id" {
  description = "ID of the security group for EC2 instance"
  value       = aws_security_group.flask_app.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instance (from IAM module)"
  value       = var.ec2_role_arn
}

