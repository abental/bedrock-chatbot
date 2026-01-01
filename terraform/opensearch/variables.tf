variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "bedrock_kb_role_arn" {
  description = "ARN of the Bedrock Knowledge Base IAM role"
  type        = string
}

variable "opensearch_role_arn" {
  description = "ARN of the OpenSearch Serverless IAM role (from IAM module)"
  type        = string
  default     = ""
}

variable "ec2_role_arn" {
  description = "ARN of the EC2 IAM role for OpenSearch access"
  type        = string
  default     = ""
}

variable "additional_opensearch_principals" {
  description = "Additional IAM user/role ARNs that need OpenSearch access (e.g., for index management)"
  type        = list(string)
  default     = []
}

