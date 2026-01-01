#!/bin/bash
# Script to import existing BedrockKnowledgeBaseChatbotPolicy into Terraform state
# Usage: ./import-existing-policy.sh

set -e

POLICY_NAME="BedrockKnowledgeBaseChatbotPolicy"

echo "Importing existing IAM policy into Terraform state..."
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "Account ID: $ACCOUNT_ID"
echo "Policy ARN: $POLICY_ARN"
echo ""

# Check if policy exists
if ! aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✗ Error: Policy '$POLICY_NAME' not found in AWS"
    echo "   Please create it first using ./update-policy.sh or create it manually"
    exit 1
fi

echo "✓ Policy found: $POLICY_NAME"
echo ""

# Import the policy into Terraform state
# Note: This assumes iam_user_name is set in terraform.tfvars
echo "Importing policy into Terraform state..."
echo ""

terraform import 'module.iam.aws_iam_policy.bedrock_kb_chatbot_user[0]' "$POLICY_ARN"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Successfully imported policy into Terraform state"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'terraform plan' to verify the import"
    echo "  2. If there are differences, Terraform will show them"
    echo "  3. Run 'terraform apply' to sync any differences"
else
    echo ""
    echo "✗ Failed to import policy"
    echo "   Make sure:"
    echo "   - You're in the terraform directory"
    echo "   - iam_user_name is set in terraform.tfvars"
    echo "   - You have permissions to read IAM policies"
    exit 1
fi

