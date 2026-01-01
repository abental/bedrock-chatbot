variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "bedrock_embedding_model_arn" {
  description = "ARN of the Bedrock embedding model to use"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for knowledge base"
  type        = string
}

variable "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  type        = string
}

variable "bedrock_kb_role_arn" {
  description = "ARN of the Bedrock Knowledge Base IAM role"
  type        = string
}

