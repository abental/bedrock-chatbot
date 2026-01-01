# ============================================================================
# AWS Bedrock
# ============================================================================
# Note: IAM Role and policies are created in main.tf to resolve circular dependencies

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-knowledge-base"
  role_arn = var.bedrock_kb_role_arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = var.bedrock_embedding_model_arn
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = var.opensearch_collection_arn
      # Note: vector_index_name - Bedrock will create this index automatically when documents are ingested
      # Using a simple default name that Bedrock expects
      # Changed from project-specific name to simple default to match original working configuration
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "vector"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  # Note: The vector index will be created automatically by Bedrock when documents are ingested
  # The vector_index_name is just a name that Bedrock will use to create the index
  # Dependencies are handled in main.tf via module dependencies
}

# Bedrock Knowledge Base Data Source
resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id     = aws_bedrockagent_knowledge_base.main.id
  name                  = "${var.project_name}-s3-datasource"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.s3_bucket_arn
    }
  }
}

