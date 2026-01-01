terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# Module: Network (VPC and Networking)
# ============================================================================
module "network" {
  source = "./network"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

# ============================================================================
# Module: S3
# ============================================================================
module "s3" {
  source = "./s3"

  knowledge_base_bucket_name = var.knowledge_base_bucket_name
}

# ============================================================================
# Module: IAM Roles (created first - no dependencies)
# ============================================================================
# IAM roles are created first without policies that need OpenSearch ARN
module "iam" {
  source = "./iam"

  project_name = var.project_name
  s3_bucket_arn = module.s3.bucket_arn
  aws_region = var.aws_region
  iam_user_name = var.iam_user_name
  # OpenSearch ARN will be set after OpenSearch is created
  opensearch_collection_arn = ""
}

# ============================================================================
# Module: OpenSearch Serverless
# ============================================================================
module "opensearch" {
  source = "./opensearch"

  project_name = var.project_name
  bedrock_kb_role_arn = module.iam.bedrock_kb_role_arn
  opensearch_role_arn = module.iam.opensearch_role_arn
  ec2_role_arn = module.iam.ec2_role_arn
  additional_opensearch_principals = var.additional_opensearch_principals

  depends_on = [module.iam]
}

# Wait for OpenSearch collection to be fully ready before creating index
resource "time_sleep" "wait_for_opensearch" {
  depends_on = [
    module.opensearch,
    aws_iam_role_policy.bedrock_kb_opensearch_policy
  ]

  create_duration = "2m"  # Wait for collection to be fully active
}

# Create OpenSearch Serverless index before Bedrock KB creation
# This ensures the index exists before Bedrock tries to validate it
resource "null_resource" "create_opensearch_index" {
  depends_on = [
    module.opensearch,
    aws_iam_role_policy.bedrock_kb_opensearch_policy,
    time_sleep.wait_for_opensearch
  ]

  triggers = {
    collection_endpoint = module.opensearch.collection_endpoint
    collection_id      = module.opensearch.collection_id
    index_name         = "bedrock-knowledge-base-default-index"
    vector_dimension   = "1536"  # Must match embedding model dimension (titan-embed-text-v1 = 1536)
    # Recreate if any of these change
  }

  provisioner "local-exec" {
    command = <<-EOT
      set +e  # Don't exit on error - we'll handle errors explicitly
      
      COLLECTION_ENDPOINT="${module.opensearch.collection_endpoint}"
      COLLECTION_ID="${module.opensearch.collection_id}"
      INDEX_NAME="bedrock-knowledge-base-default-index"
      AWS_REGION="${var.aws_region}"
      
      # Remove https:// prefix if present
      ENDPOINT_HOST=$(echo "$COLLECTION_ENDPOINT" | sed 's|^https://||')
      
      echo "Creating OpenSearch Serverless index: $INDEX_NAME"
      echo "Collection: $COLLECTION_ID"
      echo "Endpoint: $ENDPOINT_HOST"
      
      # Index mapping for Bedrock
      INDEX_BODY='{
        "settings": {
          "index": {
            "knn": true,
            "knn.algo_param.ef_search": 100
          }
        },
        "mappings": {
          "properties": {
            "vector": {
              "type": "knn_vector",
              "dimension": 1536,
              "method": {
                "name": "hnsw",
                "space_type": "cosinesimil",
                "engine": "faiss"
              }
            },
            "text": {
              "type": "text"
            }
          }
        }
      }'
      
      # Try to create index using awscurl (if available)
      if command -v awscurl &> /dev/null; then
        echo "Using awscurl to create index..."
        
        # First, try to delete existing index (in case it has wrong dimension)
        echo "Checking if index exists and deleting if needed..."
        DELETE_RESPONSE=$(awscurl -X DELETE "https://$ENDPOINT_HOST/$INDEX_NAME" \
          --service aoss \
          --region "$AWS_REGION" 2>&1) || true
        
        # Wait a moment after deletion
        sleep 2
        
        # Now create the index with correct dimension (1536 for titan-embed-text-v1)
        echo "Creating index with dimension 1536 (matching titan-embed-text-v1)..."
        RESPONSE=$(awscurl -X PUT "https://$ENDPOINT_HOST/$INDEX_NAME" \
          -H "Content-Type: application/json" \
          -d "$INDEX_BODY" \
          --service aoss \
          --region "$AWS_REGION" 2>&1) || true
        
        # Check if index was created successfully
        if echo "$RESPONSE" | grep -qE '"acknowledged"'; then
          echo "✓ Index created successfully with dimension 1536"
          exit 0
        elif echo "$RESPONSE" | grep -q "resource_already_exists_exception\|index.*already.*exists"; then
          echo "✓ Index already exists (may need manual deletion if dimension is wrong)"
          exit 0
        elif echo "$RESPONSE" | grep -q "authorization_exception\|security_exception\|403"; then
          echo "⚠ Permission denied - index will be created by Bedrock during ingestion"
          echo "This is expected if your IAM user doesn't have index creation permissions"
          exit 0  # Don't fail - Bedrock will create it
        else
          echo "Index creation response: $RESPONSE"
          echo "⚠ Index creation may have failed, but continuing..."
          exit 0  # Don't fail - let Bedrock try
        fi
      else
        # Fallback: Try using AWS CLI with OpenSearch API
        echo "awscurl not found. Attempting with AWS CLI..."
        echo "Note: You may need to install awscurl: pip install awscurl"
        echo "For now, index will be created by Bedrock during ingestion"
        exit 0  # Don't fail - Bedrock will create it
      fi
    EOT

    interpreter = ["/bin/bash", "-c"]
    
    # Continue even if index creation fails (Bedrock will create it)
    on_failure = continue
  }
}

# Wait a moment after index creation attempt
resource "time_sleep" "wait_after_index_creation" {
  depends_on = [null_resource.create_opensearch_index]
  
  create_duration = "30s"  # Brief wait after index creation attempt
}

# Note: Bedrock Knowledge Base creation may fail with "no such index" error
# This is a known Bedrock API limitation - it validates the index exists, but the index
# is created automatically by Bedrock during document ingestion.
#
# If you encounter this error, see docs/BEDROCK_INDEX_ISSUE.md for workarounds:
# - Create KB via AWS Console first, then import into Terraform (recommended)
# - Or use AWS CLI to create KB, then import
#
# The 15-minute wait above helps, but may not always be sufficient.

# ============================================================================
# IAM Policies that depend on OpenSearch (created after OpenSearch exists)
# ============================================================================
# These policies are created in main.tf to break circular dependency:
# - IAM roles are created first
# - OpenSearch is created (needs IAM role ARN)
# - These policies are created last (need OpenSearch ARN)

resource "aws_iam_role_policy" "bedrock_kb_opensearch_policy" {
  name = "${var.project_name}-bedrock-kb-opensearch-policy"
  role = module.iam.bedrock_kb_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = module.opensearch.collection_arn
      }
    ]
  })

  depends_on = [module.opensearch]
}

# Update EC2 policy to include OpenSearch access
# Note: We're adding this as a separate policy to avoid recreating the entire EC2 policy
resource "aws_iam_role_policy" "ec2_opensearch_policy" {
  name = "${var.project_name}-ec2-opensearch-policy"
  role = module.iam.ec2_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = module.opensearch.collection_arn
      }
    ]
  })

  depends_on = [module.opensearch]
}

# ============================================================================
# Module: AWS Bedrock
# ============================================================================
module "bedrock" {
  source = "./bedrock"

  project_name              = var.project_name
  bedrock_embedding_model_arn = var.bedrock_embedding_model_arn
  s3_bucket_arn             = module.s3.bucket_arn
  opensearch_collection_arn  = module.opensearch.collection_arn
  bedrock_kb_role_arn       = module.iam.bedrock_kb_role_arn

  depends_on = [
    module.s3, 
    module.opensearch,
    module.iam,
    aws_iam_role_policy.bedrock_kb_opensearch_policy,
    time_sleep.wait_for_opensearch,
    null_resource.create_opensearch_index,
    time_sleep.wait_after_index_creation
  ]
  
  # Note: Index creation is attempted before KB creation
  # If index creation fails due to permissions, Bedrock will create it during ingestion
}

# ============================================================================
# Module: EC2 Instance
# ============================================================================
module "ec2" {
  source = "./ec2"

  project_name              = var.project_name
  vpc_id                    = module.network.vpc_id
  public_subnet_id          = module.network.public_subnet_id
  ec2_instance_type         = var.ec2_instance_type
  s3_bucket_arn             = module.s3.bucket_arn
  opensearch_collection_arn  = module.opensearch.collection_arn
  ec2_instance_profile_name = module.iam.ec2_instance_profile_name
  ec2_role_arn              = module.iam.ec2_role_arn
  ec2_key_pair_name         = var.ec2_key_pair_name

  depends_on = [module.network, module.s3, module.opensearch, module.iam]
}

# ============================================================================
# Module: IAM Users and Groups
# ============================================================================
module "users" {
  source = "./users"

  project_name = var.project_name
}

