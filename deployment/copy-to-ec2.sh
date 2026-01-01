#!/bin/bash
# Copy deployment files to EC2 instance
# This script runs on your local machine and copies src/, config/, and deployment/ directories to EC2
# Usage: ./copy-to-ec2.sh <ec2-user>@<ec2-host> [--key <key-file>]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
EC2_HOST=""
#KEY_FILE="$HOME/.ssh/bedrock-chatbot-key.pem"
KEY_FILE=""
REMOTE_DIR="/tmp/bedrock-chatbot-deploy"

while [[ $# -gt 0 ]]; do
    case $1 in
        --key)
            KEY_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 <ec2-user>@<ec2-host> [--key <key-file>]"
            echo ""
            echo "Examples:"
            echo "  $0 ubuntu@ec2-1-2-3-4.compute-1.amazonaws.com"
            echo "  $0 ubuntu@1.2.3.4 --key ~/.ssh/my-key.pem"
            echo ""
            exit 0
            ;;
        *)
            if [ -z "$EC2_HOST" ]; then
                EC2_HOST="$1"
            else
                log_error "Unknown option: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate EC2 host
if [ -z "$EC2_HOST" ]; then
    log_error "EC2 host is required"
    echo "Usage: $0 <ec2-user>@<ec2-host> [--key <key-file>]"
    echo "Example: $0 ubuntu@ec2-1-2-3-4.compute-1.amazonaws.com --key ~/.ssh/my-key.pem"
    exit 1
fi

# Get project root directory (parent of deployment/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOYMENT_DIR="$PROJECT_ROOT/deployment"

log_info "🚀 Copying Bedrock Chatbot files to EC2"
log_info "=================================================="
log_info "EC2 Host: $EC2_HOST"
log_info "Project Root: $PROJECT_ROOT"
log_info "Remote Directory: $REMOTE_DIR"
echo ""

# Build SSH command
SSH_CMD="ssh"
SCP_CMD="scp"
if [ -n "$KEY_FILE" ]; then
    if [ ! -f "$KEY_FILE" ]; then
        log_error "Key file not found: $KEY_FILE"
        exit 1
    fi
    SSH_CMD="ssh -i $KEY_FILE"
    SCP_CMD="scp -i $KEY_FILE"
    log_info "Using SSH key: $KEY_FILE"
fi

# Test SSH connection
log_info "🔌 Testing SSH connection..."
if ! $SSH_CMD -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$EC2_HOST" "echo 'Connection successful'" > /dev/null 2>&1; then
    log_error "Failed to connect to $EC2_HOST"
    log_info "Please check:"
    log_info "  1. EC2 instance is running"
    log_info "  2. Security group allows SSH (port 22) from your IP"
    log_info "  3. SSH key is correct (if using --key)"
    log_info "  4. Username is correct (usually 'ubuntu' for Ubuntu AMIs)"
    exit 1
fi
log_success "SSH connection successful"

# Create remote directory
log_info "📁 Creating remote directory..."
$SSH_CMD "$EC2_HOST" "mkdir -p $REMOTE_DIR/src $REMOTE_DIR/config $REMOTE_DIR/deployment"
log_success "Remote directories created"

# Copy src directory
if [ -d "$PROJECT_ROOT/src" ]; then
    log_info "📋 Copying src/ directory..."
    $SCP_CMD -r "$PROJECT_ROOT/src"/* "$EC2_HOST:$REMOTE_DIR/src/"
    log_success "src/ directory copied"
else
    log_error "src/ directory not found at $PROJECT_ROOT/src"
    exit 1
fi

# Copy config directory
if [ -d "$PROJECT_ROOT/config" ]; then
    log_info "📋 Copying config/ directory..."
    $SCP_CMD -r "$PROJECT_ROOT/config"/* "$EC2_HOST:$REMOTE_DIR/config/"
    log_success "config/ directory copied"
else
    log_warning "config/ directory not found at $PROJECT_ROOT/config"
    log_info "Creating empty config directory on remote..."
    $SSH_CMD "$EC2_HOST" "mkdir -p $REMOTE_DIR/config"
fi

# Copy deployment directory
if [ -d "$DEPLOYMENT_DIR" ]; then
    log_info "📋 Copying deployment/ directory..."
    $SCP_CMD -r "$DEPLOYMENT_DIR"/* "$EC2_HOST:$REMOTE_DIR/deployment/"
    log_success "deployment/ directory copied"
else
    log_error "deployment/ directory not found at $DEPLOYMENT_DIR"
    exit 1
fi

# Copy requirements.txt if it exists at project root
if [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    log_info "📋 Copying requirements.txt..."
    $SCP_CMD "$PROJECT_ROOT/requirements.txt" "$EC2_HOST:$REMOTE_DIR/"
    log_success "requirements.txt copied"
fi

# Make deploy script executable
log_info "🔧 Making deployment script executable..."
$SSH_CMD "$EC2_HOST" "chmod +x $REMOTE_DIR/deployment/deploy-on-ec2.sh"
log_success "Deployment script is now executable"

echo ""
log_success "✅ Files copied successfully!"
echo ""
log_info "📝 Next steps:"
echo "1. SSH into the EC2 instance:"
if [ -n "$KEY_FILE" ]; then
    echo "   ssh -i $KEY_FILE $EC2_HOST"
else
    echo "   ssh $EC2_HOST"
fi
echo ""
echo "2. Run the deployment script:"
echo "   sudo $REMOTE_DIR/deployment/deploy-on-ec2.sh"
echo ""
echo "   Or run it directly via SSH:"
if [ -n "$KEY_FILE" ]; then
    echo "   ssh -i $KEY_FILE $EC2_HOST 'sudo $REMOTE_DIR/deployment/deploy-on-ec2.sh'"
else
    echo "   ssh $EC2_HOST 'sudo $REMOTE_DIR/deployment/deploy-on-ec2.sh'"
fi
echo ""


