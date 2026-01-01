#!/bin/bash
# Script to create OpenSearch Serverless index and then Bedrock Knowledge Base
# This works around Bedrock's validation that requires the index to exist

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Bedrock Knowledge Base Creation Script${NC}"
echo "This script creates the OpenSearch index first, then the Knowledge Base"
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

# Step 2: Create the index using OpenSearch API
if [ "$SKIP_INDEX" = true ]; then
    echo -e "${YELLOW}Step 2: Skipping index creation (--skip-index flag)${NC}"
else
    echo -e "${YELLOW}Step 2: Creating OpenSearch Serverless index...${NC}"

    if [ -z "$COLLECTION_ENDPOINT" ]; then
        echo -e "${YELLOW}Warning: Collection endpoint not available. Trying to get it from AWS...${NC}"
        COLLECTION_ENDPOINT=$(aws opensearchserverless get-collection --id "$COLLECTION_ID" --region "$AWS_REGION" --query 'collectionDetail.collectionEndpoint' --output text 2>/dev/null || echo "")
    fi

    if [ -z "$COLLECTION_ENDPOINT" ]; then
        echo -e "${RED}Error: Could not get collection endpoint${NC}"
        exit 1
    fi

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

    # Remove https:// prefix if present (endpoint may already include it)
    ENDPOINT_HOST=$(echo "$COLLECTION_ENDPOINT" | sed 's|^https://||')
    
    echo "Creating index: $INDEX_NAME"
    echo "Endpoint: https://$ENDPOINT_HOST"

    # Check if awscurl is available
    if command -v awscurl &> /dev/null; then
        echo "Using awscurl to create index..."
        INDEX_RESPONSE=$(awscurl -X PUT "https://$ENDPOINT_HOST/$INDEX_NAME" \
          -H "Content-Type: application/json" \
          -d "$INDEX_BODY" \
          --service aoss \
          --region "$AWS_REGION" 2>&1)
        INDEX_EXIT_CODE=$?
        
        # Check for success (201 Created) or if index already exists (400 Bad Request with "resource_already_exists_exception")
        if [ $INDEX_EXIT_CODE -eq 0 ] && echo "$INDEX_RESPONSE" | grep -qE '"acknowledged"|"resource_already_exists_exception"'; then
            echo -e "${GREEN}✓ Index created successfully or already exists${NC}"
        elif echo "$INDEX_RESPONSE" | grep -q "authorization_exception\|security_exception"; then
            echo -e "${RED}✗ Permission denied: You don't have permissions to create the index${NC}"
            echo ""
            echo -e "${YELLOW}This is expected - regular IAM users cannot create indices in OpenSearch Serverless.${NC}"
            echo -e "${YELLOW}Only service roles (like Bedrock) can create indices.${NC}"
            echo ""
            echo -e "${YELLOW}Alternative: Create the index via AWS Console or use a workaround:${NC}"
            echo "1. Go to AWS Console → OpenSearch Serverless"
            echo "2. Select your collection"
            echo "3. Try to create index there (may also require special permissions)"
            echo ""
            echo -e "${YELLOW}OR: We'll try to create the KB anyway - Bedrock may create the index during ingestion${NC}"
            echo -e "${YELLOW}(This will likely fail, but we'll try)${NC}"
        else
            echo -e "${YELLOW}Index creation response:${NC}"
            echo "$INDEX_RESPONSE"
            echo -e "${YELLOW}Continuing anyway...${NC}"
        fi
        echo ""
        echo -e "${YELLOW}Waiting for index to be available...${NC}"
        sleep 5
    else
        echo -e "${RED}awscurl not found!${NC}"
        echo ""
        echo -e "${YELLOW}You have two options:${NC}"
        echo ""
        echo "Option 1: Install awscurl (recommended)"
        echo "  pip install awscurl"
        echo "  Then run this script again"
        echo ""
        echo "Option 2: Create index via AWS Console"
        echo "  1. Go to: https://console.aws.amazon.com/aos/home"
        echo "  2. Select your collection: $COLLECTION_ID"
        echo "  3. Go to 'Indexes' tab"
        echo "  4. Click 'Create Index'"
        echo "  5. Name: $INDEX_NAME"
        echo "  6. Use the index mapping from the script (see below)"
        echo "  7. Then run this script again with --skip-index flag"
        echo ""
        echo "Index mapping to use:"
        echo "$INDEX_BODY" | jq . 2>/dev/null || echo "$INDEX_BODY"
        echo ""
        read -p "Continue anyway? (KB creation will likely fail) (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Exiting. Please create the index first.${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Continuing without index creation...${NC}"
    fi
fi

echo ""

# Step 3: Create Knowledge Base

# Step 4: Create Knowledge Base
echo -e "${YELLOW}Step 4: Creating Bedrock Knowledge Base...${NC}"

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
    echo -e "${YELLOW}Step 5: Import into Terraform...${NC}"
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
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. The index may not be fully ready yet. Wait a few minutes and try again."
    echo "2. Check IAM permissions for the Bedrock role."
    echo "3. Verify the OpenSearch collection is in ACTIVE state."
    echo "4. Try creating the KB via AWS Console instead."
    exit 1
fi

