#!/bin/bash
# Script to check the actual OpenSearch index mapping

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Checking OpenSearch Index Mapping${NC}"
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

echo -e "${YELLOW}Fetching index mapping...${NC}"
MAPPING_RESPONSE=$(awscurl -X GET "https://$ENDPOINT_HOST/$INDEX_NAME/_mapping" \
  --service aoss \
  --region "$AWS_REGION" 2>&1)

if echo "$MAPPING_RESPONSE" | grep -q "index_not_found_exception"; then
    echo -e "${RED}✗ Index does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}Current index mapping:${NC}"
echo "$MAPPING_RESPONSE" | jq '.' 2>/dev/null || echo "$MAPPING_RESPONSE"

# Check if metadata field exists in mapping
if echo "$MAPPING_RESPONSE" | grep -q '"metadata"'; then
    echo ""
    echo -e "${YELLOW}⚠ Metadata field found in mapping:${NC}"
    echo "$MAPPING_RESPONSE" | jq '.[] | .mappings.properties.metadata' 2>/dev/null || echo "Could not parse metadata field"
fi

