# ============================================================================
# S3 Bucket for Knowledge Base
# ============================================================================

resource "aws_s3_bucket" "knowledge_base" {
  bucket = var.knowledge_base_bucket_name

  tags = {
    Name        = var.knowledge_base_bucket_name
    Description = "S3 bucket for Bedrock Knowledge Base"
  }
}

resource "aws_s3_bucket_versioning" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets  = true
}





