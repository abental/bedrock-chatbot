#!/bin/bash
# Terraform apply command for all modules except EC2 instance
# This allows you to create the infrastructure without the EC2 instance

set -e

echo "Applying Terraform configuration (excluding EC2 instance)..."
echo ""

cd "$(dirname "$0")"

terraform apply \
  -target=module.network \
  -target=module.s3 \
  -target=module.iam \
  -target=module.opensearch \
  -target=aws_iam_role_policy.bedrock_kb_opensearch_policy \
  -target=aws_iam_role_policy.ec2_opensearch_policy \
  -target=time_sleep.wait_for_opensearch \
  -target=null_resource.create_opensearch_index \
  -target=time_sleep.wait_after_index_creation \
  -target=module.bedrock \
  -target=module.users

echo ""
echo "✅ Terraform apply completed (EC2 instance excluded)"
echo ""
echo "To create the EC2 instance later, run:"
echo "  terraform apply -target=module.ec2"
echo ""
echo "Or to apply everything including EC2:"
echo "  terraform apply"





