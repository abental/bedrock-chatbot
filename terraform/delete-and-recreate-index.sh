#!/bin/bash
# Script to delete and recreate the OpenSearch index with correct mapping
# This ensures Bedrock doesn't create it with the wrong metadata mapping

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Delete and Recreate OpenSearch Index${NC}"
echo "This will delete the existing index and recreate it without metadata mapping"
echo ""

# Get values from Terraform outputs
if [ -f "terraform.tfstate" ] || [ -f "../terraform.tfstate" ]; then
    echo "Reading values from Terraform outputs..."
    COLLECTION_ENDPOINT=$(terraform output -json 2>/dev/null | jq -r '.opensearch_collection_endpoint.value // empty' || echo "")
    INDEX_NAME="bedrock-knowledge-base-default-index"
    AWS_REGION=$(terraform output -json 2>/dev/null | jq -r '.aws_region.value // "us-east-1"' || echo "us-east-1")
else
    echo -e "${YELLOW}Warning: terraform.tfstate not found. Please provide values manually.${NC}"
    read -p "OpenSearch Collection Endpoint: " COLLECTION_ENDPOINT
    read -p "Index Name [bedrock-knowledge-base-default-index]: " INDEX_NAME
    INDEX_NAME=${INDEX_NAME:-bedrock-knowledge-base-default-index}
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
fi

if [ -z "$COLLECTION_ENDPOINT" ]; then
    echo -e "${RED}Error: Collection endpoint is required${NC}"
    exit 1
fi

# Remove https:// prefix if present
ENDPOINT_HOST=$(echo "$COLLECTION_ENDPOINT" | sed 's|^https://||')

# Check if awscurl is available
if ! command -v awscurl &> /dev/null; then
    echo -e "${RED}Error: awscurl is required but not installed${NC}"
    echo "Install it with: pip install awscurl"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Collection Endpoint: $COLLECTION_ENDPOINT"
echo "  Index Name: $INDEX_NAME"
echo "  AWS Region: $AWS_REGION"
echo ""

echo -e "${YELLOW}⚠ WARNING: This will delete all indexed documents!${NC}"
echo "You will need to re-sync your data source after this."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 1: Deleting existing index...${NC}"
DELETE_RESPONSE=$(awscurl -X DELETE "https://$ENDPOINT_HOST/$INDEX_NAME" \
  --service aoss \
  --region "$AWS_REGION" 2>&1)

if echo "$DELETE_RESPONSE" | grep -qE '"acknowledged"|"index_not_found_exception"'; then
    echo -e "${GREEN}✓ Index deleted (or didn't exist)${NC}"
else
    echo -e "${YELLOW}⚠ Delete response:${NC}"
    echo "$DELETE_RESPONSE"
fi

echo "Waiting 10 seconds for deletion to complete..."
sleep 10

echo ""
echo -e "${YELLOW}Step 2: Creating index WITHOUT metadata field mapping...${NC}"
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

CREATE_RESPONSE=$(awscurl -X PUT "https://$ENDPOINT_HOST/$INDEX_NAME" \
  -H "Content-Type: application/json" \
  -d "$INDEX_BODY" \
  --service aoss \
  --region "$AWS_REGION" 2>&1)

if echo "$CREATE_RESPONSE" | grep -qE '"acknowledged"'; then
    echo -e "${GREEN}✓ Index created successfully${NC}"
    echo ""
    echo -e "${GREEN}✓ Index recreated without metadata field mapping${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update Terraform to remove metadata_field from Bedrock configuration"
    echo "2. Run: terraform apply"
    echo "3. Re-sync your Bedrock Knowledge Base data source"
else
    echo -e "${RED}✗ Failed to create index${NC}"
    echo "$CREATE_RESPONSE"
    exit 1
fi

