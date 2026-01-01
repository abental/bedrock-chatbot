# ============================================================================
# Network Outputs
# ============================================================================
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.network.private_subnet_id
}

# ============================================================================
# S3 Outputs
# ============================================================================
output "s3_bucket_name" {
  description = "Name of the S3 bucket for knowledge base"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for knowledge base"
  value       = module.s3.bucket_arn
}

# ============================================================================
# OpenSearch Outputs
# ============================================================================
output "opensearch_collection_id" {
  description = "ID of the OpenSearch Serverless collection"
  value       = module.opensearch.collection_id
}

output "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  value       = module.opensearch.collection_arn
}

output "opensearch_collection_endpoint" {
  description = "Endpoint of the OpenSearch Serverless collection"
  value       = module.opensearch.collection_endpoint
}

output "opensearch_role_arn" {
  description = "ARN of the IAM role for OpenSearch Serverless"
  value       = module.opensearch.opensearch_role_arn
}

# ============================================================================
# Bedrock Outputs
# ============================================================================
output "bedrock_knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base"
  value       = module.bedrock.knowledge_base_id
}

output "bedrock_knowledge_base_arn" {
  description = "ARN of the Bedrock Knowledge Base"
  value       = module.bedrock.knowledge_base_arn
}

output "bedrock_data_source_id" {
  description = "ID of the Bedrock Knowledge Base data source"
  value       = module.bedrock.data_source_id
}

output "bedrock_kb_role_arn" {
  description = "ARN of the IAM role for Bedrock Knowledge Base"
  value       = module.iam.bedrock_kb_role_arn
}

# ============================================================================
# EC2 Outputs
# ============================================================================
output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "ec2_instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.instance_public_ip
}

output "ec2_instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = module.ec2.instance_public_dns
}

output "ec2_security_group_id" {
  description = "ID of the security group for EC2 instance"
  value       = module.ec2.security_group_id
}

output "ec2_iam_role_arn" {
  description = "ARN of the IAM role for EC2 instance"
  value       = module.ec2.iam_role_arn
}

# ============================================================================
# Users and Groups Outputs
# ============================================================================
output "application_user_name" {
  description = "Name of the application IAM user"
  value       = module.users.application_user_name
}

output "application_user_arn" {
  description = "ARN of the application IAM user"
  value       = module.users.application_user_arn
}

output "application_group_name" {
  description = "Name of the application-group IAM group"
  value       = module.users.application_group_name
}

output "application_group_arn" {
  description = "ARN of the application-group IAM group"
  value       = module.users.application_group_arn
}

