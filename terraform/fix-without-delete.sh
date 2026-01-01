#!/bin/bash
# Alternative fix: Check metadata.json files in S3 and provide solutions
# Since we can't delete the index, we need to work with what we have

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}Alternative Fix for Metadata Mapping Error${NC}"
echo "Since we cannot delete the index, let's check for other causes"
echo ""

# Get S3 bucket from Terraform
if [ -f "terraform.tfstate" ] || [ -f "../terraform.tfstate" ]; then
    S3_BUCKET=$(terraform output -json 2>/dev/null | jq -r '.s3_bucket_name.value // "abt-bedrock-kb-store"' || echo "abt-bedrock-kb-store")
else
    read -p "S3 Bucket Name [abt-bedrock-kb-store]: " S3_BUCKET
    S3_BUCKET=${S3_BUCKET:-abt-bedrock-kb-store}
fi

echo "Checking for metadata.json files in S3..."
echo "Bucket: $S3_BUCKET"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is required${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking for metadata.json files...${NC}"
METADATA_FILES=$(aws s3 ls "s3://$S3_BUCKET/documents/" --recursive 2>/dev/null | grep "metadata.json" || echo "")

if [ -z "$METADATA_FILES" ]; then
    echo -e "${GREEN}✓ No metadata.json files found${NC}"
    echo ""
    echo -e "${YELLOW}Step 2: Checking index mapping...${NC}"
    echo "The issue is likely that Bedrock created the index with metadata as object type."
    echo ""
    echo -e "${BLUE}Solution Options:${NC}"
    echo ""
    echo "Option 1: Remove metadata_field from Bedrock KB configuration"
    echo "  - Edit terraform/bedrock/main.tf"
    echo "  - Remove or comment out: metadata_field = \"metadata\""
    echo "  - Run: terraform apply"
    echo "  - Re-sync data source"
    echo ""
    echo "Option 2: Contact AWS Support"
    echo "  - Request index deletion permissions"
    echo "  - Or request help with metadata mapping issue"
    echo ""
    echo "Option 3: Use Bedrock service role to delete index"
    echo "  - The Bedrock KB role might have permissions to delete the index"
    echo "  - You would need to assume that role temporarily"
else
    echo -e "${YELLOW}Found metadata.json files. Checking their content...${NC}"
    echo ""
    
    # Sample a few files
    SAMPLE_FILES=$(echo "$METADATA_FILES" | head -3)
    
    for file_info in $SAMPLE_FILES; do
        file_path=$(echo "$file_info" | awk '{print $4}')
        echo -e "${BLUE}Checking: $file_path${NC}"
        
        # Download and check content
        TEMP_FILE=$(mktemp)
        aws s3 cp "s3://$S3_BUCKET/$file_path" "$TEMP_FILE" 2>/dev/null || continue
        
        # Check if it's a string (not valid JSON object)
        if ! jq empty "$TEMP_FILE" 2>/dev/null; then
            echo -e "${RED}  ✗ Invalid JSON${NC}"
        elif echo "$(cat $TEMP_FILE)" | jq -e 'type == "string"' 2>/dev/null; then
            echo -e "${RED}  ✗ Contains string value (should be object)${NC}"
            echo "  Content: $(cat $TEMP_FILE | head -c 100)"
        elif echo "$(cat $TEMP_FILE)" | jq -e 'type == "object"' 2>/dev/null; then
            echo -e "${GREEN}  ✓ Valid JSON object${NC}"
        else
            echo -e "${YELLOW}  ⚠ Unexpected format${NC}"
        fi
        
        rm -f "$TEMP_FILE"
    done
    
    echo ""
    echo -e "${YELLOW}If any metadata.json files contain strings instead of objects,${NC}"
    echo "you need to fix them in S3. They should be JSON objects like:"
    echo '  {"key": "value", "another": "field"}'
    echo ""
    echo "Not strings like:"
    echo '  "some string value"'
fi

echo ""
echo -e "${YELLOW}Step 3: Recommended Action${NC}"
echo ""
echo "Since you cannot delete the index, try this:"
echo ""
echo "1. Remove metadata_field from Bedrock KB configuration:"
echo "   Edit: terraform/bedrock/main.tf"
echo "   Change field_mapping to:"
echo "   field_mapping {"
echo "     vector_field = \"vector\""
echo "     text_field   = \"text\""
echo "     # metadata_field removed"
echo "   }"
echo ""
echo "2. Apply Terraform:"
echo "   terraform apply"
echo ""
echo "3. This will update the Bedrock KB to not use metadata_field"
echo "   Bedrock will still store metadata, but won't enforce object type"
echo ""
echo "4. Re-sync your data source"

