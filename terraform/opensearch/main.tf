# ============================================================================
# OpenSearch Serverless
# ============================================================================
# Note: IAM Role and policies are created in the IAM module

# OpenSearch Serverless Encryption Policy
resource "aws_opensearchserverless_security_policy" "encryption" {
  name     = "${var.project_name}-encryption-policy"
  type     = "encryption"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/${var.project_name}-knowledge-base"
        ]
      }
    ]
    AWSOwnedKey = true
  })
}

# OpenSearch Serverless Network Policy
resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.project_name}-network-policy"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${var.project_name}-knowledge-base"
          ]
        },
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${var.project_name}-knowledge-base"
          ]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# Build list of principals for OpenSearch data access policy
locals {
  opensearch_principals = distinct(compact(concat(
    [var.bedrock_kb_role_arn],
    var.ec2_role_arn != "" ? [var.ec2_role_arn] : [],
    var.additional_opensearch_principals
  )))
}

# OpenSearch Serverless Data Access Policy
resource "aws_opensearchserverless_access_policy" "data" {
  name        = "${var.project_name}-data-access-policy"
  type        = "data"
  description = "Data access policy for Bedrock Knowledge Base, EC2 role, and additional principals"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${var.project_name}-knowledge-base"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource = [
            "index/${var.project_name}-knowledge-base/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = local.opensearch_principals
    }
  ])
}

# OpenSearch Serverless Collection
resource "aws_opensearchserverless_collection" "knowledge_base" {
  name = "${var.project_name}-knowledge-base"
  type = "VECTORSEARCH"

  tags = {
    Name = "${var.project_name}-knowledge-base"
  }

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data
  ]
}

