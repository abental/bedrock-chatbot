#!/bin/bash
# Script to create and attach IAM policy for Bedrock KB Chatbot
# Usage: ./attach-policy.sh [USER_NAME] [POLICY_TYPE]
#   USER_NAME: IAM user name (default: dev)
#   POLICY_TYPE: full or minimal (default: full)

set -e

USER_NAME=${1:-dev}
POLICY_TYPE=${2:-full}

if [ "$POLICY_TYPE" = "minimal" ]; then
    POLICY_FILE="iam-policy-bedrock-kb-minimal.json"
    POLICY_NAME="BedrockKnowledgeBaseChatbotPolicyMinimal"
else
    POLICY_FILE="iam-policy-bedrock-kb.json"
    POLICY_NAME="BedrockKnowledgeBaseChatbotPolicy"
fi

echo "Creating IAM policy: $POLICY_NAME"
echo "For user: $USER_NAME"
echo "Using policy file: $POLICY_FILE"
echo ""

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo "Error: Policy file not found: $POLICY_FILE"
    exit 1
fi

# Create the policy
echo "Step 1: Creating policy..."
POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://$POLICY_FILE" \
    --description "Policy for Bedrock KB Chatbot application" \
    --query 'Policy.Arn' \
    --output text 2>&1)

# Check if policy already exists
if [[ $POLICY_ARN == *"EntityAlreadyExists"* ]]; then
    echo "Policy already exists. Getting ARN..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    echo "Policy ARN: $POLICY_ARN"
else
    echo "Policy created successfully!"
    echo "Policy ARN: $POLICY_ARN"
fi

echo ""
echo "Step 2: Attaching policy to user: $USER_NAME..."

# Attach policy to user
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$POLICY_ARN"

echo "Policy attached successfully!"
echo ""
echo "Step 3: Verifying attachment..."

# Verify attachment
aws iam list-attached-user-policies --user-name "$USER_NAME" | grep -q "$POLICY_NAME" && \
    echo "✓ Policy verification successful!" || \
    echo "⚠ Warning: Could not verify policy attachment"

echo ""
echo "Done! The policy has been attached to user: $USER_NAME"
echo ""
echo "Note: It may take a few minutes for IAM changes to propagate."
echo "If you still see permission errors, wait 1-2 minutes and try again."

