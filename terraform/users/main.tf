# ============================================================================
# IAM Users and Groups
# ============================================================================

# ============================================================================
# IAM User: application
# ============================================================================
resource "aws_iam_user" "application" {
  name = "application"

  tags = {
    Name = "application"
  }
}

# ============================================================================
# IAM Group: application-group
# ============================================================================
resource "aws_iam_group" "application_group" {
  name = "application-group"
}

# ============================================================================
# IAM Group Policy: AWS Marketplace Bedrock Permissions
# ============================================================================
resource "aws_iam_group_policy" "application_group_marketplace_bedrock" {
  name  = "application-group-marketplace-bedrock-policy"
  group = aws_iam_group.application_group.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MarketplaceBedrock"
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Unsubscribe",
          "aws-marketplace:Subscribe"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Add User to Group
# ============================================================================
resource "aws_iam_user_group_membership" "application_group_membership" {
  user = aws_iam_user.application.name

  groups = [
    aws_iam_group.application_group.name
  ]
}





