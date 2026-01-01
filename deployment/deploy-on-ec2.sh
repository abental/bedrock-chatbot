#!/bin/bash
# Deployment script for Bedrock Knowledge Base Chatbot on EC2
# This script runs ON the EC2 instance and deploys the application
# It expects src/, config/, and deployment/ directories to be in /tmp/bedrock-chatbot-deploy/
# Usage: sudo ./deploy-on-ec2.sh

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

# Configuration
SOURCE_DIR="/tmp/bedrock-chatbot-deploy"
APP_DIR="/app"

log_info "🚀 Bedrock Knowledge Base Chatbot Deployment Script"
log_info "=================================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run with sudo"
    exit 1
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory not found: $SOURCE_DIR"
    log_info "Please run copy-to-ec2.sh first to copy files to EC2"
    exit 1
fi

# Detect Ubuntu
if [ ! -f /etc/os-release ]; then
    log_error "Cannot detect operating system"
    exit 1
fi

if ! grep -q "Ubuntu" /etc/os-release; then
    log_warning "This script is designed for Ubuntu. Detected OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system packages
log_info "📦 Updating system packages..."
apt-get update -y

log_info "📦 Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    build-essential \
    gcc \
    libssl-dev \
    libbz2-dev \
    libffi-dev \
    zlib1g-dev \
    libreadline-dev \
    libsqlite3-dev \
    curl \
    wget \
    software-properties-common \
    nginx

log_success "System dependencies installed"

# Create application directory
log_info "📁 Creating application directory: $APP_DIR"
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/data"
mkdir -p "$APP_DIR/logs"
mkdir -p /tmp/uploads
chmod 777 /tmp/uploads

# Copy application code from source directory
log_info "📋 Copying application code from $SOURCE_DIR..."
if [ -d "$SOURCE_DIR/src" ]; then
    cp -r "$SOURCE_DIR/src"/* "$APP_DIR/"
    log_success "Application code copied"
else
    log_error "Source directory not found: $SOURCE_DIR/src"
    exit 1
fi

# Copy config directory
if [ -d "$SOURCE_DIR/config" ]; then
    log_info "📋 Copying config directory..."
    mkdir -p "$APP_DIR/config"
    cp -r "$SOURCE_DIR/config"/* "$APP_DIR/config/"
    log_success "Config directory copied"
    
    # Set proper permissions for admin_password.txt
    if [ -f "$APP_DIR/config/admin_password.txt" ]; then
        chmod 600 "$APP_DIR/config/admin_password.txt"
        if id "ubuntu" &>/dev/null; then
            chown ubuntu:ubuntu "$APP_DIR/config/admin_password.txt"
        elif [ -n "$SUDO_USER" ]; then
            chown $SUDO_USER:$SUDO_USER "$APP_DIR/config/admin_password.txt"
        fi
        log_success "Admin password file permissions set"
    fi
else
    log_warning "Config directory not found at $SOURCE_DIR/config"
    log_info "Creating empty config directory (admin_password.txt will need to be created manually)"
    mkdir -p "$APP_DIR/config"
fi

# Copy requirements.txt
if [ -f "$SOURCE_DIR/requirements.txt" ]; then
    cp "$SOURCE_DIR/requirements.txt" "$APP_DIR/"
elif [ -f "$SOURCE_DIR/src/requirements.txt" ]; then
    cp "$SOURCE_DIR/src/requirements.txt" "$APP_DIR/"
else
    log_warning "requirements.txt not found, creating default..."
    cat > "$APP_DIR/requirements.txt" <<EOF
Flask==3.1.2
boto3==2.49.0
python-dotenv==1.2.1
Werkzeug==3.1.4
Flask-Limiter==3.5.0
WTForms==3.1.2
gunicorn
EOF
fi

# Create virtual environment
log_info "🐍 Creating Python virtual environment..."
cd "$APP_DIR"
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
log_info "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install --no-cache-dir -r requirements.txt
pip install --no-cache-dir gunicorn

log_success "Python dependencies installed"

# Set up environment variables
log_info "⚙️  Setting up environment variables..."
ENV_DIR="/etc/bedrock-chatbot"
mkdir -p "$ENV_DIR"

# Check if environment script exists in deployment directory
ENV_SCRIPT="$SOURCE_DIR/deployment/set-env-vars.sh"
if [ -f "$ENV_SCRIPT" ]; then
    log_info "Running environment setup script..."
    bash "$ENV_SCRIPT"
    log_success "Environment variables configured"
else
    log_info "Creating basic environment file..."
    
    # Generate a stable Flask secret key if not already set
    if [ -f "$ENV_DIR/env.conf" ] && grep -q "^FLASK_SECRET_KEY=" "$ENV_DIR/env.conf" && ! grep -q "^FLASK_SECRET_KEY=$" "$ENV_DIR/env.conf"; then
        # Secret key already exists and is not empty, preserve it
        FLASK_SECRET_KEY=$(grep "^FLASK_SECRET_KEY=" "$ENV_DIR/env.conf" | cut -d'=' -f2-)
        log_info "Preserving existing FLASK_SECRET_KEY"
    else
        # Generate a new secret key
        FLASK_SECRET_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
        log_info "Generated new FLASK_SECRET_KEY"
    fi
    
    cat > "$ENV_DIR/env.conf" <<EOF
# Bedrock Knowledge Base Chatbot Environment Variables
APP_PORT=8080
FLASK_ENV=production
FLASK_DEBUG=False
AWS_REGION=us-east-1
LOG_LEVEL=INFO
LOG_TO_FILE=true
APP_DIR=$APP_DIR
VENV_DIR=$APP_DIR/venv
UPLOAD_FOLDER=/tmp/uploads
ADMIN_PASSWORD_FILE=$APP_DIR/config/admin_password.txt
DB_PATH=$APP_DIR/data/chatbot.db
FLASK_SECRET_KEY=$FLASK_SECRET_KEY

# Bedrock Configuration (REQUIRED - set these values)
# KNOWLEDGE_BASE_ID=your-knowledge-base-id
# MODEL_ID=anthropic.claude-3-5-sonnet-20240620-v1:0
# S3_BUCKET_NAME=your-s3-bucket-name

# Optional: Max tokens and temperature for model invocation
# MAX_TOKENS=1000
# TEMPERATURE=0.7
EOF
    log_success "Basic environment file created"
fi

# Set ownership
log_info "👤 Setting file ownership..."
chown -R ubuntu:ubuntu "$APP_DIR" 2>/dev/null || chown -R $SUDO_USER:$SUDO_USER "$APP_DIR" 2>/dev/null || true
chown -R ubuntu:ubuntu /tmp/uploads 2>/dev/null || chown -R $SUDO_USER:$SUDO_USER /tmp/uploads 2>/dev/null || true

log_success "File ownership set"

# Create systemd service file
log_info "🔧 Creating systemd service..."
SERVICE_FILE="/etc/systemd/system/bedrock-chatbot.service"

# Check if service file exists in deployment directory
SERVICE_SOURCE="$SOURCE_DIR/deployment/bedrock-chatbot.service"
if [ -f "$SERVICE_SOURCE" ]; then
    # Use the service file from deployment directory
    cp "$SERVICE_SOURCE" "$SERVICE_FILE"
    log_success "Systemd service file copied from deployment directory"
else
    # Create service file
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Bedrock Knowledge Base Chatbot Flask Application
After=network.target

[Service]
Type=notify
User=ubuntu
Group=ubuntu
WorkingDirectory=$APP_DIR
EnvironmentFile=-$ENV_DIR/env.conf
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:8080 --timeout 120 --chdir $APP_DIR app:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bedrock-chatbot

[Install]
WantedBy=multi-user.target
EOF
    log_success "Systemd service file created"
fi

# Reload systemd
log_info "🔄 Reloading systemd daemon..."
systemctl daemon-reload
log_success "Systemd daemon reloaded"

# Setup NGINX reverse proxy
log_info "🌐 Setting up NGINX reverse proxy..."
NGINX_CONF_SOURCE="$SOURCE_DIR/deployment/nginx-bedrock-chatbot.conf"

if [ -f "$NGINX_CONF_SOURCE" ]; then
    # Copy NGINX configuration
    cp "$NGINX_CONF_SOURCE" /etc/nginx/sites-available/bedrock-chatbot
    
    # Create symlink to enable site
    if [ ! -L /etc/nginx/sites-enabled/bedrock-chatbot ]; then
        ln -s /etc/nginx/sites-available/bedrock-chatbot /etc/nginx/sites-enabled/
    fi
    
    # Remove default NGINX site if it exists
    if [ -L /etc/nginx/sites-enabled/default ]; then
        rm /etc/nginx/sites-enabled/default
    fi
    
    # Test NGINX configuration
    if nginx -t; then
        log_success "NGINX configuration is valid"
        # Reload NGINX
        systemctl reload nginx
        log_success "NGINX reloaded"
        
        # Enable NGINX on boot
        systemctl enable nginx
        log_success "NGINX enabled on boot"
    else
        log_error "NGINX configuration test failed"
        exit 1
    fi
else
    log_warning "NGINX configuration file not found, creating basic configuration..."
    tee /etc/nginx/sites-available/bedrock-chatbot > /dev/null <<EOF
upstream bedrock_chatbot {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;

    client_max_body_size 50M;
    
    location / {
        proxy_pass http://bedrock_chatbot;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/bedrock-chatbot /etc/nginx/sites-enabled/
    if [ -L /etc/nginx/sites-enabled/default ]; then
        rm /etc/nginx/sites-enabled/default
    fi
    if nginx -t; then
        systemctl reload nginx
        systemctl enable nginx
        log_success "Basic NGINX configuration created and enabled"
    else
        log_error "NGINX configuration test failed"
        exit 1
    fi
fi

echo ""
log_success "✅ Deployment complete!"
echo ""
log_info "📝 Next steps:"
echo "1. Edit environment variables (REQUIRED):"
echo "   sudo nano $ENV_DIR/env.conf"
echo ""
echo "   Set the following (get values from Terraform outputs):"
echo "   KNOWLEDGE_BASE_ID=<your-kb-id>"
echo "   MODEL_ID=anthropic.claude-3-5-sonnet-20240620-v1:0"
echo "   S3_BUCKET_NAME=<your-bucket-name>"
echo ""
echo "2. Enable and start the service:"
echo "   sudo systemctl enable bedrock-chatbot"
echo "   sudo systemctl start bedrock-chatbot"
echo ""
echo "3. Check service status:"
echo "   sudo systemctl status bedrock-chatbot"
echo ""
echo "4. View logs:"
echo "   sudo journalctl -u bedrock-chatbot -f"
echo ""
echo "5. Test the application:"
echo "   curl http://localhost:8080/api/health"
echo "   curl http://localhost/api/health  # via NGINX on port 80"
echo ""
echo "6. NGINX is configured to proxy port 80 to 8080"
echo "   Access the application at: http://<ec2-ip>/"
echo ""

