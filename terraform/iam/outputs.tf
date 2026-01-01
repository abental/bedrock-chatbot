output "bedrock_kb_role_arn" {
  description = "ARN of the IAM role for Bedrock Knowledge Base"
  value       = aws_iam_role.bedrock_knowledge_base.arn
}

output "bedrock_kb_role_id" {
  description = "ID of the IAM role for Bedrock Knowledge Base"
  value       = aws_iam_role.bedrock_knowledge_base.id
}

output "bedrock_kb_role_name" {
  description = "Name of the IAM role for Bedrock Knowledge Base"
  value       = aws_iam_role.bedrock_knowledge_base.name
}

output "opensearch_role_arn" {
  description = "ARN of the IAM role for OpenSearch Serverless"
  value       = aws_iam_role.opensearch_serverless.arn
}

output "opensearch_role_id" {
  description = "ID of the IAM role for OpenSearch Serverless"
  value       = aws_iam_role.opensearch_serverless.id
}

output "ec2_role_arn" {
  description = "ARN of the IAM role for EC2 instance"
  value       = aws_iam_role.ec2_flask_app.arn
}

output "ec2_role_id" {
  description = "ID of the IAM role for EC2 instance"
  value       = aws_iam_role.ec2_flask_app.id
}

output "ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for EC2"
  value       = aws_iam_instance_profile.ec2_flask_app.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the IAM instance profile for EC2"
  value       = aws_iam_instance_profile.ec2_flask_app.arn
}

output "bedrock_kb_policy_arn" {
  description = "ARN of the IAM policy for Bedrock Knowledge Base"
  value       = aws_iam_policy.bedrock_knowledge_base.arn
}

output "bedrock_kb_chatbot_user_policy_arn" {
  description = "ARN of the IAM policy for Bedrock KB Chatbot user (if iam_user_name is set)"
  value       = var.iam_user_name != "" ? aws_iam_policy.bedrock_kb_chatbot_user[0].arn : null
}

