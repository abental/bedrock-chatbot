#!/bin/bash
# Script to fix OpenSearch metadata mapping issue
# This script updates the index mapping to handle metadata as both object and string

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}OpenSearch Metadata Mapping Fix${NC}"
echo "This script will update the index mapping to fix metadata type conflicts"
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

echo ""
echo "Configuration:"
echo "  Collection Endpoint: $COLLECTION_ENDPOINT"
echo "  Index Name: $INDEX_NAME"
echo "  AWS Region: $AWS_REGION"
echo ""

# Remove https:// prefix if present
ENDPOINT_HOST=$(echo "$COLLECTION_ENDPOINT" | sed 's|^https://||')

# Check if awscurl is available
if ! command -v awscurl &> /dev/null; then
    echo -e "${RED}Error: awscurl is required but not installed${NC}"
    echo "Install it with: pip install awscurl"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking if index exists...${NC}"
INDEX_EXISTS=$(awscurl -X HEAD "https://$ENDPOINT_HOST/$INDEX_NAME" \
  --service aoss \
  --region "$AWS_REGION" 2>&1 | grep -q "200 OK" && echo "yes" || echo "no")

if [ "$INDEX_EXISTS" = "no" ]; then
    echo -e "${YELLOW}Index does not exist. Creating with correct mapping...${NC}"
    
    # Create index with flexible metadata mapping
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
    
    RESPONSE=$(awscurl -X PUT "https://$ENDPOINT_HOST/$INDEX_NAME" \
      -H "Content-Type: application/json" \
      -d "$INDEX_BODY" \
      --service aoss \
      --region "$AWS_REGION" 2>&1)
    
    if echo "$RESPONSE" | grep -qE '"acknowledged"|"resource_already_exists_exception"'; then
        echo -e "${GREEN}✓ Index created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create index${NC}"
        echo "$RESPONSE"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Index exists${NC}"
    echo -e "${YELLOW}Step 2: Updating index mapping...${NC}"
    
    # Note: OpenSearch doesn't allow removing fields from mapping once documents exist
    # We need to delete and recreate the index without the metadata field definition
    echo -e "${YELLOW}Note: The index has documents with conflicting metadata types.${NC}"
    echo "OpenSearch cannot change field types once documents exist."
    echo "We need to delete and recreate the index without the explicit metadata mapping."
    echo ""
    read -p "Do you want to delete and recreate the index? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting index...${NC}"
        DELETE_RESPONSE=$(awscurl -X DELETE "https://$ENDPOINT_HOST/$INDEX_NAME" \
          --service aoss \
          --region "$AWS_REGION" 2>&1)
        
        echo "Waiting 10 seconds for deletion to complete..."
        sleep 10
        
        echo -e "${YELLOW}Recreating index with correct mapping...${NC}"
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
            echo -e "${GREEN}✓ Index recreated successfully${NC}"
            echo -e "${YELLOW}⚠ You will need to re-sync your data source to re-index documents${NC}"
        else
            echo -e "${RED}✗ Failed to recreate index${NC}"
            echo "$CREATE_RESPONSE"
            exit 1
        fi
    else
        echo -e "${YELLOW}Index not recreated. You may need to manually delete and recreate it.${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✓ Metadata mapping fix completed${NC}"
echo ""
echo "Next steps:"
echo "1. Re-sync your Bedrock Knowledge Base data source"
echo "2. The metadata field will be handled dynamically by OpenSearch (no explicit mapping)"
echo "3. This allows Bedrock to write metadata as either object or string without conflicts"

