variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type for Flask application"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  type        = string
}

variable "ec2_instance_profile_name" {
  description = "Name of the IAM instance profile for EC2"
  type        = string
}

variable "ec2_role_arn" {
  description = "ARN of the IAM role for EC2 instance (from IAM module)"
  type        = string
  default     = ""
}

variable "ec2_key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access (must exist in AWS)"
  type        = string
  default     = ""
}

