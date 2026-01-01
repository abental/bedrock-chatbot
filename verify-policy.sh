#!/bin/bash
# Script to verify and update IAM policy
# Usage: ./verify-policy.sh

set -e

POLICY_NAME="BedrockKnowledgeBaseChatbotPolicy"
POLICY_FILE="iam-policy-bedrock-kb.json"
ROLE_NAME="abt-chatbot-bedrock-kb-role"

echo "Verifying IAM policy configuration..."
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "Account ID: $ACCOUNT_ID"
echo "Policy ARN: $POLICY_ARN"
echo ""

# Check if policy exists
if aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✓ Policy exists: $POLICY_NAME"
    
    # Get current policy version
    CURRENT_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
    echo "Current default version: $CURRENT_VERSION"
    
    # Get current policy document
    echo ""
    echo "Current policy document:"
    aws iam get-policy-version \
        --policy-arn "$POLICY_ARN" \
        --version-id "$CURRENT_VERSION" \
        --query 'PolicyVersion.Document' \
        --output json | jq '.' || echo "Could not parse policy (jq not installed)"
    
    echo ""
    echo "Creating new policy version..."
    
    # Create new policy version
    NEW_VERSION=$(aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document "file://$POLICY_FILE" \
        --set-as-default \
        --query 'PolicyVersion.VersionId' \
        --output text 2>&1)
    
    if [[ $NEW_VERSION == *"LimitExceeded"* ]]; then
        echo "⚠ Policy version limit reached. Need to delete old versions first."
        echo ""
        echo "Listing all policy versions:"
        aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[*].[VersionId,IsDefaultVersion,CreateDate]' --output table
        
        echo ""
        echo "To fix this, delete old non-default versions:"
        echo "aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id <VERSION_ID>"
    else
        echo "✓ New policy version created: $NEW_VERSION"
        echo "✓ Set as default version"
    fi
else
    echo "✗ Policy does not exist. Creating new policy..."
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "file://$POLICY_FILE" \
        --description "Unified policy for Bedrock KB Chatbot application and KB role"
    
    echo "✓ Policy created"
fi

echo ""
echo "Checking if policy is attached to role: $ROLE_NAME"

# Check if attached to role
if aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text | grep -q "$POLICY_ARN"; then
    echo "✓ Policy is attached to role: $ROLE_NAME"
else
    echo "✗ Policy is NOT attached to role: $ROLE_NAME"
    echo ""
    echo "Attaching policy to role..."
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN"
    echo "✓ Policy attached to role"
fi

echo ""
echo "Verification complete!"
echo ""
echo "Note: Wait 1-2 minutes for IAM changes to propagate before testing."

