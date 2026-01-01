# Terraform Commands Reference

## Apply Configuration Without EC2 Instance

### Option 1: Using `-target` (Recommended - No Code Changes)

Apply all resources except the EC2 module:

```bash
cd /Users/israelbental/my_code/Bedrock_KB_project/terraform

# Apply everything except EC2
terraform apply \
  -target=module.network \
  -target=module.s3 \
  -target=module.iam \
  -target=module.opensearch \
  -target=aws_iam_role_policy.bedrock_kb_opensearch_policy \
  -target=aws_iam_role_policy.ec2_opensearch_policy \
  -target=module.bedrock \
  -target=module.users
```

Or use a more concise approach by targeting the root module and excluding EC2:

```bash
# Plan without EC2
terraform plan | grep -v "module.ec2"

# Apply specific modules (exclude EC2)
terraform apply \
  -target=module.network \
  -target=module.s3 \
  -target=module.iam \
  -target=module.opensearch \
  -target=module.bedrock \
  -target=module.users \
  -target=aws_iam_role_policy.bedrock_kb_opensearch_policy \
  -target=aws_iam_role_policy.ec2_opensearch_policy
```

### Option 2: Comment Out EC2 Module (Requires Code Change)

Temporarily comment out the EC2 module in `main.tf`:

```hcl
# ============================================================================
# Module: EC2 Instance (Temporarily disabled)
# ============================================================================
# module "ec2" {
#   source = "./ec2"
#   ...
# }
```

Then run:
```bash
terraform apply
```

**Remember to uncomment when you want to create the EC2 instance later!**

### Option 3: Use a Variable to Control EC2 Creation

Add a variable to conditionally create EC2:

```hcl
variable "create_ec2_instance" {
  description = "Whether to create the EC2 instance"
  type        = bool
  default     = false
}
```

Then in `main.tf`:
```hcl
module "ec2" {
  count = var.create_ec2_instance ? 1 : 0
  source = "./ec2"
  ...
}
```

Apply with:
```bash
terraform apply -var="create_ec2_instance=false"
```

---

## Other Useful Terraform Commands

### Plan Without EC2
```bash
terraform plan | grep -v "module.ec2"
```

### Destroy Everything Except EC2
```bash
terraform destroy \
  -target=module.users \
  -target=module.bedrock \
  -target=module.opensearch \
  -target=module.iam \
  -target=module.s3 \
  -target=module.network
```

### Apply Only Specific Module
```bash
# Apply only S3
terraform apply -target=module.s3

# Apply only Bedrock
terraform apply -target=module.bedrock
```

### Refresh State Without EC2
```bash
terraform refresh -target=module.network -target=module.s3 -target=module.iam -target=module.opensearch -target=module.bedrock -target=module.users
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `terraform plan` | Preview changes |
| `terraform apply` | Apply all changes |
| `terraform apply -target=module.X` | Apply specific module |
| `terraform destroy` | Destroy all resources |
| `terraform destroy -target=module.X` | Destroy specific module |
| `terraform refresh` | Update state file |
| `terraform output` | Show output values |





