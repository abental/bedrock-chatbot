variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection (not used - policies created in main.tf)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for resource ARNs"
  type        = string
}

variable "iam_user_name" {
  description = "IAM user name to attach the Bedrock KB policy to (e.g., 'dev')"
  type        = string
  default     = ""
}

