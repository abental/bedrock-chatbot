#!/bin/bash
# Script to update IAM policy with embedding model permissions
# Usage: ./update-policy.sh

set -e

POLICY_NAME="BedrockKnowledgeBaseChatbotPolicy"
POLICY_FILE="iam-policy-bedrock-kb.json"
ROLE_NAME="abt-chatbot-bedrock-kb-role"
USER_NAME="dev"

echo "Updating IAM policy: $POLICY_NAME"
echo ""

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo "✗ Error: Policy file not found: $POLICY_FILE"
    echo "   Please run this script from the project root directory"
    exit 1
fi

# Validate JSON syntax
if ! jq empty "$POLICY_FILE" 2>/dev/null; then
    echo "✗ Error: Invalid JSON in policy file: $POLICY_FILE"
    exit 1
fi

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "Account ID: $ACCOUNT_ID"
echo "Policy ARN: $POLICY_ARN"
echo "Policy file: $POLICY_FILE"
echo ""

# Check if policy exists
if aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✓ Policy exists: $POLICY_NAME"
    
    # List current versions
    echo ""
    echo "Current policy versions:"
    aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[*].[VersionId,IsDefaultVersion,CreateDate]' --output table
    
    # Try to create new version
    echo ""
    echo "Creating new policy version with updated permissions..."
    
    # Capture both stdout and stderr separately
    OUTPUT=$(aws iam create-policy-version \
        --policy-arn "$POLICY_ARN" \
        --policy-document "file://$POLICY_FILE" \
        --set-as-default \
        --query 'PolicyVersion.VersionId' \
        --output text 2>&1)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -ne 0 ]; then
        if [[ "$OUTPUT" == *"LimitExceeded"* ]]; then
            echo ""
            echo "⚠ Policy version limit reached (max 5 versions)."
            echo "Deleting oldest non-default version..."
            
            # Get non-default versions, sorted by date (oldest first)
            OLD_VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" \
                --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
                --output text | tr '\t' '\n' | head -1)
            
            if [ -n "$OLD_VERSIONS" ]; then
                for VERSION in $OLD_VERSIONS; do
                    echo "Deleting version: $VERSION"
                    aws iam delete-policy-version \
                        --policy-arn "$POLICY_ARN" \
                        --version-id "$VERSION" || true
                done
                
                # Try again
                echo ""
                echo "Creating new policy version..."
                OUTPUT=$(aws iam create-policy-version \
                    --policy-arn "$POLICY_ARN" \
                    --policy-document "file://$POLICY_FILE" \
                    --set-as-default \
                    --query 'PolicyVersion.VersionId' \
                    --output text 2>&1)
                EXIT_CODE=$?
                
                if [ $EXIT_CODE -eq 0 ]; then
                    echo "✓ New policy version created: $OUTPUT"
                else
                    echo "✗ Failed to create policy version after deleting old version:"
                    echo "$OUTPUT"
                    exit 1
                fi
            else
                echo "✗ Could not find non-default version to delete"
                echo "Please manually delete an old version in AWS Console"
                exit 1
            fi
        else
            echo "✗ Failed to create policy version:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "✓ New policy version created: $OUTPUT"
    fi
    
    # Verify the update
    echo ""
    echo "Verifying policy update..."
    DEFAULT_VERSION=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
    echo "✓ Default version is now: $DEFAULT_VERSION"
    
    echo "✓ Policy updated and set as default"
else
    echo "✗ Policy does not exist. Creating new policy..."
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "file://$POLICY_FILE" \
        --description "Unified policy for Bedrock KB Chatbot application and KB role"
    
    echo "✓ Policy created"
fi

echo ""
echo "Verifying policy attachments..."

# Check if attached to role
if aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text 2>/dev/null | grep -q "$POLICY_ARN"; then
    echo "✓ Policy is attached to role: $ROLE_NAME"
else
    echo "⚠ Policy is NOT attached to role: $ROLE_NAME"
    echo ""
    echo "The Knowledge Base service role needs this policy to invoke embedding models during sync."
    read -p "Attach policy to role '$ROLE_NAME'? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Attaching policy to role..."
        if aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn "$POLICY_ARN" 2>&1; then
            echo "✓ Policy attached to role"
        else
            echo "✗ Failed to attach policy to role. You may need to attach it manually."
        fi
    fi
fi

# Check if attached to user
if aws iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text 2>/dev/null | grep -q "$POLICY_ARN"; then
    echo "✓ Policy is attached to user: $USER_NAME"
else
    echo "⚠ Policy is NOT attached to user: $USER_NAME"
    echo ""
    read -p "Attach policy to user '$USER_NAME'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Attaching policy to user..."
        aws iam attach-user-policy \
            --user-name "$USER_NAME" \
            --policy-arn "$POLICY_ARN"
        echo "✓ Policy attached to user"
    fi
fi

echo ""
echo "=========================================="
echo "Policy update complete!"
echo "=========================================="
echo ""
echo "The policy now includes:"
echo "  ✓ Bedrock Knowledge Base access"
echo "  ✓ Bedrock query operations (RetrieveAndGenerate)"
echo "  ✓ Bedrock Agent operations (InvokeAgent)"
echo "  ✓ Claude foundation models (for responses)"
echo "  ✓ Titan embedding models (for document processing)"
echo "  ✓ S3 document storage access"
echo ""
echo "⚠ IMPORTANT: Wait 1-2 minutes for IAM changes to propagate"
echo "   Then try the sync operation again."

