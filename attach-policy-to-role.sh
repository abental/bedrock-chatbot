#!/bin/bash
# Quick script to attach BedrockKnowledgeBaseChatbotPolicy to the KB service role

set -e

POLICY_NAME="BedrockKnowledgeBaseChatbotPolicy"
ROLE_NAME="abt-chatbot-bedrock-kb-role"

echo "Attaching policy to Knowledge Base service role..."
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "Account ID: $ACCOUNT_ID"
echo "Policy ARN: $POLICY_ARN"
echo "Role Name: $ROLE_NAME"
echo ""

# Check if policy exists
if ! aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✗ Error: Policy '$POLICY_NAME' does not exist"
    echo "   Please run ./update-policy.sh first to create/update the policy"
    exit 1
fi

# Check if role exists
if ! aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
    echo "✗ Error: Role '$ROLE_NAME' does not exist"
    exit 1
fi

# Check if already attached
if aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text 2>/dev/null | grep -q "$POLICY_ARN"; then
    echo "✓ Policy is already attached to role: $ROLE_NAME"
    exit 0
fi

# Attach the policy
echo "Attaching policy to role..."
if aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"; then
    echo "✓ Policy successfully attached to role: $ROLE_NAME"
    echo ""
    echo "⚠ IMPORTANT: Wait 1-2 minutes for IAM changes to propagate"
    echo "   Then try the sync operation again."
else
    echo "✗ Failed to attach policy to role"
    exit 1
fi

