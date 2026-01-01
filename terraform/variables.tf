variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "abt-chatbot"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "knowledge_base_bucket_name" {
  description = "Name of the S3 bucket for the knowledge base"
  type        = string
  default     = "abt-bedrock-kb-store"
}

variable "bedrock_embedding_model_arn" {
  description = "ARN of the Bedrock embedding model to use"
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for Flask application"
  type        = string
  default     = "t3.small"
}

variable "additional_opensearch_principals" {
  description = "Additional IAM user/role ARNs that need OpenSearch Serverless access (e.g., for index management). Example: [\"arn:aws:iam::ACCOUNT:user/dev\"]"
  type        = list(string)
  default     = []
}

variable "iam_user_name" {
  description = "IAM user name to attach the Bedrock KB Chatbot policy to (e.g., 'dev'). Leave empty to skip user policy attachment."
  type        = string
  default     = "dev"
}

variable "ec2_key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access. Must exist in AWS. Leave empty if you don't need SSH access or will use Session Manager."
  type        = string
  default     = "bedrock-chatbot-key"
}

