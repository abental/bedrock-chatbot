output "collection_id" {
  description = "ID of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base.id
}

output "collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base.arn
}

output "collection_endpoint" {
  description = "Endpoint of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.knowledge_base.collection_endpoint
}

output "opensearch_role_arn" {
  description = "ARN of the IAM role for OpenSearch Serverless (from IAM module)"
  value       = var.opensearch_role_arn
}

