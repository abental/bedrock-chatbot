# IAM Policy Setup for Bedrock Knowledge Base

## Overview

This guide explains how to create and attach the IAM policy required for the Bedrock Knowledge Base Chatbot application.

**Note**: The policy file (`iam-policy-bedrock-kb.json`) includes permissions for both:
1. **Application User/Role** - For API calls from the application
2. **Knowledge Base Service Role** - For ingestion/sync operations

## Required Permissions

The policy includes permissions for:

### Application User/Role Permissions
- **Bedrock**: Get/list knowledge bases, data sources, start ingestion jobs
- **Bedrock**: Query knowledge bases (RetrieveAndGenerate)
- **Bedrock**: Invoke foundation models (OpenAI GPT OSS 120B or Claude Sonnet 3.5)
- **Bedrock**: Invoke agents (InvokeAgent) - for Bedrock Agent operations
- **S3**: Upload/download documents for the knowledge base

### Knowledge Base Service Role Permissions
- **Bedrock**: Invoke embedding models (for document processing during sync)
- **S3**: Read documents from S3 bucket
- **Bedrock**: Access knowledge base resources

---

## Option 1: Using AWS Console (Recommended)

### Step 1: Create the Policy

1. Go to [IAM Console](https://console.aws.amazon.com/iam/)
2. Click **Policies** in the left sidebar
3. Click **Create policy**
4. Click the **JSON** tab
5. Copy and paste the contents from `iam-policy-bedrock-kb.json`
6. Click **Next**
7. Name the policy: `BedrockKnowledgeBaseChatbotPolicy`
8. Add description: `Policy for Bedrock KB Chatbot application`
9. Click **Create policy**

### Step 2: Attach Policy to User

1. Go to **Users** in the left sidebar
2. Click on your user (e.g., `dev`)
3. Click **Add permissions** → **Attach policies directly**
4. Search for `BedrockKnowledgeBaseChatbotPolicy`
5. Check the box next to the policy
6. Click **Add permissions**

---

## Option 2: Using AWS CLI

### Step 1: Create the Policy

```bash
# Create the policy
aws iam create-policy \
  --policy-name BedrockKnowledgeBaseChatbotPolicy \
  --policy-document file://iam-policy-bedrock-kb.json \
  --description "Policy for Bedrock KB Chatbot application"
```

This will output a policy ARN like:
```
arn:aws:iam::123456789012:policy/BedrockKnowledgeBaseChatbotPolicy
```

### Step 2: Attach Policy to User

```bash
# Replace USER_NAME with your IAM user name (e.g., "dev")
# Replace POLICY_ARN with the ARN from step 1
aws iam attach-user-policy \
  --user-name dev \
  --policy-arn arn:aws:iam::123456789012:policy/BedrockKnowledgeBaseChatbotPolicy
```

### Step 3: Verify Attachment

```bash
# List policies attached to user
aws iam list-attached-user-policies --user-name dev

# Get policy details
aws iam get-policy --policy-arn arn:aws:iam::123456789012:policy/BedrockKnowledgeBaseChatbotPolicy
```

### Step 4: Attach Policy to Knowledge Base Role (Required for Sync)

The same policy must also be attached to the Knowledge Base service role:

```bash
# Attach to Knowledge Base role
aws iam attach-role-policy \
  --role-name abt-chatbot-bedrock-kb-role \
  --policy-arn arn:aws:iam::123456789012:policy/BedrockKnowledgeBaseChatbotPolicy

# Verify attachment
aws iam list-attached-role-policies --role-name abt-chatbot-bedrock-kb-role
```

---

## Option 3: Using Terraform (Recommended)

The provided Terraform configuration in this project automatically creates and attaches all necessary IAM policies:

```bash
cd terraform
terraform init
terraform apply
```

The Terraform modules handle:
- IAM roles for Bedrock KB, OpenSearch, and EC2
- IAM policies with correct permissions
- Policy attachments to roles
- EC2 instance profile with all necessary permissions

**Note**: The Terraform configuration includes all required permissions for:
- Bedrock operations (foundation models, knowledge base, agents)
- S3 operations (document storage)
- OpenSearch operations (vector search)

If you need to manually create policies, you can reference the Terraform IAM module or use the manual options above.

---

## Policy Files

### Full Policy (`iam-policy-bedrock-kb.json`)

This policy includes all permissions needed for the application:
- Bedrock Agent operations (get/list KB, data sources, ingestion jobs)
- Bedrock Agent Runtime (query KB)
- Bedrock Foundation Models (invoke OpenAI GPT OSS 120B or Claude Sonnet 3.5)
- S3 operations (upload/download documents)

**Use this for production or if you need full functionality.**

### Minimal Policy (`iam-policy-bedrock-kb-minimal.json`)

This is a minimal policy with only the essential permissions:
- Get Knowledge Base
- List Data Sources
- Start Ingestion Job
- Retrieve and Generate (query KB)
- S3 operations

**Use this if you want to follow least-privilege principles.**

---

## Customizing the Policy

### Change S3 Bucket Name

If your S3 bucket name is different, update the resource ARN:

```json
{
  "Resource": [
    "arn:aws:s3:::your-bucket-name",
    "arn:aws:s3:::your-bucket-name/*"
  ]
}
```

### Change Knowledge Base ID

### Policy Uses Wildcards for Flexibility

The policy uses wildcards (`*`) to allow access to all knowledge bases in your account:
- `arn:aws:bedrock:us-east-1:123456789012:knowledge-base/*` - All KBs in your account

**Benefits:**
- ✅ No need to update the policy when creating new knowledge bases
- ✅ Works with multiple knowledge bases automatically
- ✅ More flexible for development and testing

**If you need to restrict to specific KBs** (for production security), replace the wildcard with specific KB IDs:

```json
{
  "Resource": [
    "arn:aws:bedrock:us-east-1:123456789012:knowledge-base/SPECIFIC_KB_ID_1",
    "arn:aws:bedrock:us-east-1:123456789012:knowledge-base/SPECIFIC_KB_ID_2"
  ]
}
```

### Restrict to Specific Region

Replace `*` with your region (e.g., `us-east-1`):

```json
{
  "Resource": [
    "arn:aws:bedrock:us-east-1:*:knowledge-base/*"
  ]
}
```

---

## Testing the Policy

After attaching the policy, test it:

```bash
# Test Bedrock access
aws bedrock-agent get-knowledge-base \
  --knowledge-base-id T3N9V5MUG \
  --region us-east-1

# Test S3 access
aws s3 ls s3://abt-bedrock-kb-store/

# Test from application
# The application should now work without permission errors
```

---

## Troubleshooting

### Error: "User is not authorized to perform: bedrock:GetKnowledgeBase"

**Cause**: Policy not attached or incorrect permissions

**Solution**:
1. Verify policy is attached: `aws iam list-attached-user-policies --user-name dev`
2. Check policy contents match the required permissions
3. Wait a few minutes for IAM changes to propagate
4. Try logging out and back in to refresh credentials

### Error: "Access Denied" for S3

**Cause**: S3 bucket name mismatch or missing permissions

**Solution**:
1. Verify bucket name in policy matches your actual bucket
2. Check S3 bucket policy allows your user
3. Ensure `s3:ListBucket` permission is included

### Policy Changes Not Taking Effect

**Cause**: IAM propagation delay or cached credentials

**Solution**:
1. Wait 1-5 minutes for IAM changes to propagate
2. Refresh credentials: `aws sts get-caller-identity`
3. Restart the application

---

## Security Best Practices

1. **Use Least Privilege**: Start with minimal policy, add permissions as needed
2. **Resource-Specific**: Use specific resource ARNs instead of `*` when possible
3. **Regular Review**: Periodically review and audit IAM policies
4. **Separate Policies**: Create separate policies for different environments (dev/staging/prod)
5. **Use IAM Roles**: Prefer IAM roles over user policies for EC2/ECS/Lambda

---

## Policy Breakdown

### Bedrock Agent Permissions

- `bedrock-agent:GetKnowledgeBase` - Get KB details (required for status endpoint)
- `bedrock-agent:ListKnowledgeBases` - List all KBs (optional, for discovery)
- `bedrock-agent:GetDataSource` - Get data source details (optional)
- `bedrock-agent:ListDataSources` - List data sources (required for status)
- `bedrock-agent:StartIngestionJob` - Start sync/ingestion (required for admin sync)
- `bedrock-agent:GetIngestionJob` - Get ingestion job status (optional)

### Bedrock Agent Runtime Permissions

- `bedrock:Retrieve` - Retrieve documents (optional)
- `bedrock:RetrieveAndGenerate` - Query KB (required for chatbot)
- `bedrock:InvokeAgent` - Invoke Bedrock Agents (required for agent operations)

### S3 Permissions

- `s3:PutObject` - Upload documents (required for admin upload)
- `s3:GetObject` - Download documents (required for KB access)
- `s3:ListBucket` - List bucket contents (required for browsing)
- `s3:DeleteObject` - Delete documents (optional, for cleanup)

---

## Attaching Policy to Knowledge Base Role

**Important**: The same policy file (`iam-policy-bedrock-kb.json`) must also be attached to the Knowledge Base service role. This is required for sync/ingestion operations to work properly.

### Error: "not authorized to perform: bedrock:InvokeModel on resource: amazon.titan-embed-text-v1"

This error occurs when the Knowledge Base role doesn't have permission to invoke the embedding model.

### Setup for Knowledge Base Role

#### Option A: Using AWS CLI

```bash
# 1. Create the policy (if not already created)
aws iam create-policy \
  --policy-name BedrockKnowledgeBaseChatbotPolicy \
  --policy-document file://iam-policy-bedrock-kb.json \
  --description "Policy for Bedrock KB Chatbot application and KB role"

# 2. Attach to Knowledge Base role (replace POLICY_ARN with output from step 1)
aws iam attach-role-policy \
  --role-name abt-chatbot-bedrock-kb-role \
  --policy-arn arn:aws:iam::123456789012:policy/BedrockKnowledgeBaseChatbotPolicy
```

#### Option B: Using AWS Console

1. Go to IAM → **Roles** → Find `abt-chatbot-bedrock-kb-role`
2. Click **Add permissions** → **Attach policies directly**
3. Search for and select `BedrockKnowledgeBaseChatbotPolicy`
4. Click **Add permissions**

### Policy Contents for KB Role

The unified policy includes all permissions needed by the KB role:
- **Bedrock Embedding Model**: `bedrock:InvokeModel` for `amazon.titan-embed-text-v1` (required for document embedding during sync)
- **S3 Access**: `s3:GetObject` and `s3:ListBucket` (required to read documents from S3)
- **KB Access**: `bedrock:GetKnowledgeBase` and `bedrock:GetDataSource` (required for KB operations)
- **All other permissions**: The same permissions as the application user (for consistency)

### Finding Your KB Role Name

```bash
aws bedrock-agent get-knowledge-base \
  --knowledge-base-id T3N9VU5MUG \
  --region us-east-1 \
  --query 'knowledgeBase.roleArn'
```

This will output the role ARN. Extract the role name from the ARN (format: `arn:aws:iam::ACCOUNT:role/ROLE_NAME`).

---

## Additional Resources

- [AWS IAM Policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
- [Bedrock IAM Permissions](https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html)
- [S3 IAM Permissions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-actions.html)

