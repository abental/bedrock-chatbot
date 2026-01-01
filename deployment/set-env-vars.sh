#!/bin/bash
# Environment variables script for Bedrock Knowledge Base Chatbot
# This script creates environment variables that will be loaded by systemd service
# Place this file in /etc/bedrock-chatbot/env.conf

set -e

ENV_FILE="/etc/bedrock-chatbot/env.conf"
ENV_DIR="/etc/bedrock-chatbot"

echo "🔧 Setting up environment variables for Bedrock Chatbot"

# Create directory if it doesn't exist
sudo mkdir -p "$ENV_DIR"

# IMPORTANT: Execute bash logic BEFORE writing to the environment file
# Check if Flask secret key already exists and preserve it
if [ -f "$ENV_FILE" ] && grep -q "^FLASK_SECRET_KEY=" "$ENV_FILE" && ! grep -q "^FLASK_SECRET_KEY=$" "$ENV_FILE"; then
    # Secret key already exists and is not empty, preserve it
    FLASK_SECRET_KEY=$(grep "^FLASK_SECRET_KEY=" "$ENV_FILE" | cut -d'=' -f2-)
    echo "Preserving existing FLASK_SECRET_KEY"
else
    # Generate a new secret key (64 characters for better security)
    FLASK_SECRET_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
    echo "Generated new FLASK_SECRET_KEY"
fi

# Create environment file with KEY=VALUE pairs only
# NOTE: Systemd EnvironmentFile does NOT support bash logic, only simple KEY=VALUE
sudo tee "$ENV_FILE" > /dev/null <<EOF
# Bedrock Knowledge Base Chatbot Environment Variables
# This file is sourced by the systemd service

# Application Configuration
APP_PORT=8080
FLASK_ENV=production
FLASK_DEBUG=False

# AWS Configuration (using IAM role - no credentials needed)
# AWS credentials will be automatically provided by EC2 instance role
AWS_REGION=us-east-1

# Logging Configuration
LOG_LEVEL=INFO
LOG_TO_FILE=true

# Application Paths
APP_DIR=/app
VENV_DIR=/app/venv
UPLOAD_FOLDER=/tmp/uploads

# Database
DB_PATH=/app/data/chatbot.db

# Admin Password File
ADMIN_PASSWORD_FILE=/app/config/admin_password.txt

# Flask Secret Key (CRITICAL: Must be set for session persistence)
FLASK_SECRET_KEY=$FLASK_SECRET_KEY

# Bedrock Configuration
# These should be set based on your Terraform outputs
# KNOWLEDGE_BASE_ID=your-kb-id
# MODEL_ID=anthropic.claude-3-5-sonnet-20241022-v2:0
# S3_BUCKET_NAME=your-bucket-name
# MAX_TOKENS=1000
# TEMPERATURE=0.7

EOF

echo "✅ Environment variables file created: $ENV_FILE"
echo ""
echo "📝 Next steps:"
echo "1. Edit $ENV_FILE to set your specific configuration values:"
echo "   sudo nano $ENV_FILE"
echo ""
echo "2. The systemd service will automatically load these variables"
echo ""

