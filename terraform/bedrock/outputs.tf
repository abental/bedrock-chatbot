output "knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "data_source_id" {
  description = "ID of the Bedrock Knowledge Base data source"
  value       = aws_bedrockagent_data_source.s3.data_source_id
}

output "bedrock_kb_role_arn" {
  description = "ARN of the IAM role for Bedrock Knowledge Base"
  value       = var.bedrock_kb_role_arn
}

