# ============================================================================
# IAM Roles and Policies
# ============================================================================

# ============================================================================
# Bedrock Knowledge Base IAM Role
# ============================================================================
resource "aws_iam_role" "bedrock_knowledge_base" {
  name = "${var.project_name}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-bedrock-kb-role"
  }
}

# IAM Policy for Bedrock Knowledge Base to access S3
resource "aws_iam_role_policy" "bedrock_knowledge_base_s3" {
  name = "${var.project_name}-bedrock-kb-s3-policy"
  role = aws_iam_role.bedrock_knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Managed IAM Policy for Bedrock Knowledge Base
# This includes all necessary permissions for KB operations, embedding models, and querying
resource "aws_iam_policy" "bedrock_knowledge_base" {
  name        = "${var.project_name}-bedrock-kb-policy"
  description = "Comprehensive policy for Bedrock Knowledge Base service role - includes KB access, embedding models, and query operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockKnowledgeBaseAccess"
        Effect = "Allow"
        Action = [
          "bedrock:GetKnowledgeBase",
          "bedrock:ListKnowledgeBases",
          "bedrock:GetDataSource",
          "bedrock:ListDataSources",
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:knowledge-base/*",
          "arn:aws:bedrock:${var.aws_region}:*:data-source/*",
          "arn:aws:bedrock:${var.aws_region}:*:ingestion-job/*"
        ]
      },
      {
        Sid    = "BedrockKnowledgeBaseQuery"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:knowledge-base/*"
        ]
      },
      {
        Sid    = "BedrockEmbeddingModelAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v1",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-*"
        ]
      },
      {
        Sid    = "BedrockFoundationModelAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/meta.llama-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/mistral.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/cohere.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/ai21.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/openai.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/google.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/nvidia.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/stability.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/qwen.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/writer.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/twelvelabs.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/moonshot.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/minimax.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/deepseek.*"
        ]
      },
      {
        Sid    = "BedrockInferenceProfileAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:inference-profile/*"
        ]
      },
      {
        Sid    = "S3DocumentStorageAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-bedrock-kb-policy"
  }
}

# Attach the managed policy to the Bedrock KB role
resource "aws_iam_role_policy_attachment" "bedrock_knowledge_base" {
  role       = aws_iam_role.bedrock_knowledge_base.name
  policy_arn = aws_iam_policy.bedrock_knowledge_base.arn
}

# IAM Policy for Bedrock Knowledge Base to access OpenSearch
# Note: This policy is created in main.tf after OpenSearch collection exists
# to avoid circular dependency

# ============================================================================
# OpenSearch Serverless IAM Role
# ============================================================================
resource "aws_iam_role" "opensearch_serverless" {
  name = "${var.project_name}-opensearch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "aoss.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-opensearch-role"
  }
}

# IAM Policy for OpenSearch Serverless
resource "aws_iam_role_policy" "opensearch_serverless" {
  name = "${var.project_name}-opensearch-policy"
  role = aws_iam_role.opensearch_serverless.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# EC2 Instance IAM Role
# ============================================================================
resource "aws_iam_role" "ec2_flask_app" {
  name = "${var.project_name}-ec2-flask-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-flask-role"
  }
}

# IAM Policy for EC2 to access Bedrock, S3, and OpenSearch
resource "aws_iam_role_policy" "ec2_flask_app" {
  name = "${var.project_name}-ec2-flask-policy"
  role = aws_iam_role.ec2_flask_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:RetrieveAndGenerate",
          "bedrock:Retrieve",
          "bedrock:InvokeAgent"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:GetKnowledgeBase",
          "bedrock:ListKnowledgeBases",
          "bedrock:GetDataSource",
          "bedrock:ListDataSources",
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
      # Note: OpenSearch access policy is created in main.tf after OpenSearch exists
      # to avoid circular dependency
    ]
  })
}

# Attach BedrockKnowledgeBaseChatbotPolicy to EC2 role (same as dev user)
# This allows EC2 instance to use IAM role instead of AWS credentials
resource "aws_iam_role_policy_attachment" "ec2_bedrock_kb_chatbot_policy" {
  count      = var.iam_user_name != "" ? 1 : 0
  role       = aws_iam_role.ec2_flask_app.name
  policy_arn = aws_iam_policy.bedrock_kb_chatbot_user[0].arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_flask_app" {
  name = "${var.project_name}-flask-app-profile"
  role = aws_iam_role.ec2_flask_app.name

  tags = {
    Name = "${var.project_name}-flask-app-profile"
  }
}

# ============================================================================
# Managed IAM Policy for Application User (Bedrock KB Chatbot Policy)
# ============================================================================
resource "aws_iam_policy" "bedrock_kb_chatbot_user" {
  count       = var.iam_user_name != "" ? 1 : 0
  name        = "BedrockKnowledgeBaseChatbotPolicy"
  description = "Comprehensive policy for Bedrock KB Chatbot application user - includes KB access, foundation models, inference profiles, and query operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockKnowledgeBaseAccess"
        Effect = "Allow"
        Action = [
          "bedrock:GetKnowledgeBase",
          "bedrock:ListKnowledgeBases",
          "bedrock:GetDataSource",
          "bedrock:ListDataSources",
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:knowledge-base/*",
          "arn:aws:bedrock:${var.aws_region}:*:data-source/*",
          "arn:aws:bedrock:${var.aws_region}:*:ingestion-job/*"
        ]
      },
      {
        Sid    = "BedrockKnowledgeBaseQuery"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:knowledge-base/*"
        ]
      },
      {
        Sid    = "BedrockAgentAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeAgent"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:agent-alias/*",
          "arn:aws:bedrock:${var.aws_region}:*:agent/*"
        ]
      },
      {
        Sid    = "BedrockFoundationModelAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/meta.llama-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/mistral.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/cohere.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/ai21.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/openai.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/openai.gpt-oss-*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/google.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/nvidia.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/stability.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/qwen.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/writer.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/twelvelabs.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/moonshot.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/minimax.*",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/deepseek.*"
        ]
      },
      {
        Sid    = "BedrockInferenceProfileAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:inference-profile/*"
        ]
      },
      {
        Sid    = "BedrockEmbeddingModelAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v1",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-*"
        ]
      },
      {
        Sid    = "S3DocumentStorageAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "BedrockKnowledgeBaseChatbotPolicy"
  }
}

# Data source to reference existing IAM user
data "aws_iam_user" "application_user" {
  count = var.iam_user_name != "" ? 1 : 0
  user_name = var.iam_user_name
}

# Attach the managed policy to the IAM user
resource "aws_iam_user_policy_attachment" "bedrock_kb_chatbot_user" {
  count      = var.iam_user_name != "" ? 1 : 0
  user       = data.aws_iam_user.application_user[0].user_name
  policy_arn = aws_iam_policy.bedrock_kb_chatbot_user[0].arn
}

