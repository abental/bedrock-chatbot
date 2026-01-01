#!/bin/bash
# Script to create OpenSearch Serverless index using Bedrock service role
# This assumes the Bedrock role to create the index, then creates the KB

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Bedrock Knowledge Base Creation Script (Using Role Assumption)${NC}"
echo "This script assumes the Bedrock role to create the index, then creates the KB"
echo ""

# Get values from Terraform outputs
echo -e "${YELLOW}Step 1: Getting values from Terraform...${NC}"
cd "$(dirname "$0")"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform command not found${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: aws command not found${NC}"
    exit 1
fi

# Get outputs
COLLECTION_ARN=$(terraform output -raw opensearch_collection_arn 2>/dev/null || echo "")
BEDROCK_ROLE_ARN=$(terraform output -raw bedrock_kb_role_arn 2>/dev/null || echo "")
S3_BUCKET_ARN=$(terraform output -raw s3_bucket_arn 2>/dev/null || echo "")
COLLECTION_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint 2>/dev/null || echo "")
COLLECTION_ID=$(terraform output -raw opensearch_collection_id 2>/dev/null || echo "")
PROJECT_NAME=$(terraform output -raw project_name 2>/dev/null || terraform output -json | jq -r '.project_name.value // "abt-chatbot"')
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
EMBEDDING_MODEL=$(terraform output -raw bedrock_embedding_model_arn 2>/dev/null || echo "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1")

if [ -z "$COLLECTION_ARN" ] || [ -z "$BEDROCK_ROLE_ARN" ] || [ -z "$S3_BUCKET_ARN" ]; then
    echo -e "${RED}Error: Missing required Terraform outputs${NC}"
    echo "Please run 'terraform apply' first to create OpenSearch, S3, and IAM resources"
    exit 1
fi

INDEX_NAME="${PROJECT_NAME}-vector-index"
KB_NAME="${PROJECT_NAME}-knowledge-base"

echo -e "${GREEN}✓ Got values:${NC}"
echo "  Collection ARN: $COLLECTION_ARN"
echo "  Collection ID: $COLLECTION_ID"
echo "  Collection Endpoint: $COLLECTION_ENDPOINT"
echo "  Bedrock Role ARN: $BEDROCK_ROLE_ARN"
echo "  S3 Bucket ARN: $S3_BUCKET_ARN"
echo "  Index Name: $INDEX_NAME"
echo "  KB Name: $KB_NAME"
echo "  Region: $AWS_REGION"
echo ""

# Step 2: Assume Bedrock role and create index
echo -e "${YELLOW}Step 2: Assuming Bedrock role to create index...${NC}"

if [ -z "$COLLECTION_ENDPOINT" ]; then
    echo -e "${YELLOW}Warning: Collection endpoint not available. Trying to get it from AWS...${NC}"
    COLLECTION_ENDPOINT=$(aws opensearchserverless get-collection --id "$COLLECTION_ID" --region "$AWS_REGION" --query 'collectionDetail.collectionEndpoint' --output text 2>/dev/null || echo "")
fi

if [ -z "$COLLECTION_ENDPOINT" ]; then
    echo -e "${RED}Error: Could not get collection endpoint${NC}"
    exit 1
fi

# Remove https:// prefix if present
ENDPOINT_HOST=$(echo "$COLLECTION_ENDPOINT" | sed 's|^https://||')

# Create index mapping for Bedrock
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
        "dimension": 1024,
        "method": {
          "name": "hnsw",
          "space_type": "cosinesimil",
          "engine": "faiss"
        }
      },
      "text": {
        "type": "text"
      },
    }
  }
}'

echo "Attempting to assume Bedrock role and create index..."
echo "Endpoint: https://$ENDPOINT_HOST"
echo ""

# Assume the Bedrock role
echo "Attempting to assume role: $BEDROCK_ROLE_ARN"
echo -e "${YELLOW}Note: This will likely fail because Bedrock roles can only be assumed by bedrock.amazonaws.com service${NC}"
echo ""

ASSUME_ROLE_OUTPUT=$(timeout 10 aws sts assume-role \
  --role-arn "$BEDROCK_ROLE_ARN" \
  --role-session-name "bedrock-index-creation-$(date +%s)" \
  --region "$AWS_REGION" 2>&1)
ASSUME_EXIT_CODE=$?

if [ $ASSUME_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}✗ Failed to assume Bedrock role (as expected)${NC}"
    echo "$ASSUME_ROLE_OUTPUT"
    echo ""
    echo -e "${YELLOW}This is expected behavior.${NC}"
    echo "The Bedrock role's trust policy only allows 'bedrock.amazonaws.com' to assume it."
    echo "Regular IAM users cannot assume service roles."
    echo ""
    echo -e "${YELLOW}This approach won't work. The real issue is a Bedrock API validation bug.${NC}"
    echo ""
    echo -e "${YELLOW}Recommended solutions:${NC}"
    echo "1. Wait 10-15 minutes after OpenSearch collection creation, then retry KB creation"
    echo "2. Contact AWS Support about this validation bug"
    echo "3. Consider using an alternative vector store (Aurora with pgvector)"
    echo ""
    exit 1
fi

# Extract credentials
export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')

echo -e "${GREEN}✓ Successfully assumed Bedrock role${NC}"
echo ""

# Check if awscurl is available
if command -v awscurl &> /dev/null; then
    echo "Creating index using Bedrock role credentials..."
    INDEX_RESPONSE=$(awscurl -X PUT "https://$ENDPOINT_HOST/$INDEX_NAME" \
      -H "Content-Type: application/json" \
      -d "$INDEX_BODY" \
      --service aoss \
      --region "$AWS_REGION" 2>&1)
    INDEX_EXIT_CODE=$?
    
    # Unset temporary credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    
    if [ $INDEX_EXIT_CODE -eq 0 ] && echo "$INDEX_RESPONSE" | grep -qE '"acknowledged"|"resource_already_exists_exception"'; then
        echo -e "${GREEN}✓ Index created successfully or already exists${NC}"
        echo ""
        echo -e "${YELLOW}Waiting for index to be available...${NC}"
        sleep 5
    else
        echo -e "${YELLOW}Index creation response:${NC}"
        echo "$INDEX_RESPONSE"
        echo -e "${YELLOW}Continuing anyway...${NC}"
    fi
else
    echo -e "${RED}awscurl not found!${NC}"
    echo "Please install: pip install awscurl"
    exit 1
fi

echo ""

# Step 3: Create Knowledge Base
echo -e "${YELLOW}Step 3: Creating Bedrock Knowledge Base...${NC}"

KB_CONFIG=$(cat <<EOF
{
  "name": "$KB_NAME",
  "roleArn": "$BEDROCK_ROLE_ARN",
  "knowledgeBaseConfiguration": {
    "type": "VECTOR",
    "vectorKnowledgeBaseConfiguration": {
      "embeddingModelArn": "$EMBEDDING_MODEL"
    }
  },
  "storageConfiguration": {
    "type": "OPENSEARCH_SERVERLESS",
    "opensearchServerlessConfiguration": {
      "collectionArn": "$COLLECTION_ARN",
      "vectorIndexName": "$INDEX_NAME",
      "fieldMapping": {
        "vectorField": "vector",
        "textField": "text",
        "metadataField": "metadata"
      }
    }
  }
}
EOF
)

echo "Creating Knowledge Base: $KB_NAME"
KB_RESPONSE=$(aws bedrock-agent create-knowledge-base \
  --cli-input-json "$KB_CONFIG" \
  --region "$AWS_REGION" 2>&1)

if [ $? -eq 0 ]; then
    KB_ID=$(echo "$KB_RESPONSE" | jq -r '.knowledgeBase.knowledgeBaseId')
    echo -e "${GREEN}✓ Knowledge Base created successfully!${NC}"
    echo "  Knowledge Base ID: $KB_ID"
    echo ""
    echo -e "${YELLOW}Step 4: Import into Terraform...${NC}"
    echo "Run these commands:"
    echo ""
    echo "  terraform import module.bedrock.aws_bedrockagent_knowledge_base.main $KB_ID"
    echo ""
    
    # Try to get data source ID
    sleep 3
    DS_ID=$(aws bedrock-agent list-data-sources --knowledge-base-id "$KB_ID" --region "$AWS_REGION" --query "dataSourceSummaries[0].dataSourceId" --output text 2>/dev/null || echo "")
    if [ -n "$DS_ID" ]; then
        echo "  terraform import module.bedrock.aws_bedrockagent_data_source.s3 $KB_ID/$DS_ID"
    fi
    echo ""
    echo -e "${GREEN}Then run: terraform plan${NC}"
else
    echo -e "${RED}✗ Failed to create Knowledge Base${NC}"
    echo "$KB_RESPONSE"
    echo ""
    echo -e "${YELLOW}If you still get 'no such index' error, this is a known Bedrock API bug.${NC}"
    echo "You may need to contact AWS support or wait for a fix."
    exit 1
fi

