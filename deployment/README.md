# Deployment Scripts for Bedrock Knowledge Base Chatbot

This directory contains scripts for deploying the Bedrock Knowledge Base Chatbot to an Ubuntu EC2 instance.

## Prerequisites

1. **EC2 Instance**: Ubuntu 22.04 LTS EC2 instance with IAM role attached
2. **IAM Role**: The EC2 instance should have the same IAM role as the `dev` user (configured via Terraform)
3. **Access**: SSH access to the EC2 instance with sudo privileges
4. **SSH Key**: Your EC2 key pair file (`.pem` file)

## Quick Start

### Two-Step Deployment Process

1. **Copy files to EC2** (runs on your local machine):
   ```bash
   cd deployment
   ./copy-to-ec2.sh ubuntu@<ec2-ip-or-hostname> --key ~/.ssh/your-key.pem
   ```

2. **Deploy on EC2** (runs on EC2 instance):
   ```bash
   sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh
   ```

That's it! The application will be deployed and configured.

## Scripts Overview

### 1. `copy-to-ec2.sh` (Local Machine)

**Purpose**: Copies `src/`, `config/`, and `deployment/` directories to the EC2 instance.

**Usage:**
```bash
./copy-to-ec2.sh <ec2-user>@<ec2-host> [--key <key-file>]
```

**Examples:**
```bash
# With SSH key
./copy-to-ec2.sh ubuntu@ec2-1-2-3-4.compute-1.amazonaws.com --key ~/.ssh/my-key.pem

# Without explicit key (uses default SSH config)
./copy-to-ec2.sh ubuntu@1.2.3.4

# With IP address
./copy-to-ec2.sh ubuntu@54.123.45.67 --key ~/.ssh/bedrock-key.pem
```

**What it does:**
1. Tests SSH connection to EC2 instance
2. Creates `/tmp/bedrock-chatbot-deploy/` directory on EC2
3. Copies `src/` directory to EC2
4. Copies `config/` directory to EC2 (includes `admin_password.txt`)
5. Copies `deployment/` directory to EC2 (includes all deployment scripts)
6. Copies `requirements.txt` if it exists
7. Makes `deploy-on-ec2.sh` executable

**Output:**
- Files are copied to `/tmp/bedrock-chatbot-deploy/` on the EC2 instance
- You'll see instructions for the next step

### 2. `deploy-on-ec2.sh` (EC2 Instance)

**Purpose**: Installs dependencies, sets up the application, configures services, and deploys everything.

**Usage:**
```bash
sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh
```

**Or run directly via SSH:**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<ec2-ip> 'sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh'
```

**What it does:**
1. Updates system packages
2. Installs system dependencies (Python 3, build tools, NGINX, etc.)
3. Creates `/app` directory structure
4. Copies application code from `/tmp/bedrock-chatbot-deploy/src/` to `/app`
5. Copies config files from `/tmp/bedrock-chatbot-deploy/config/` to `/app/config`
6. Creates Python virtual environment
7. Installs Python dependencies from `requirements.txt`
8. Sets up environment variables (`/etc/bedrock-chatbot/env.conf`)
9. Creates systemd service file (`bedrock-chatbot.service`)
10. Configures NGINX reverse proxy (port 80 → 8080)
11. Sets proper file permissions
12. Reloads systemd and NGINX

**After running:**
1. Edit environment variables (REQUIRED):
   ```bash
   sudo nano /etc/bedrock-chatbot/env.conf
   ```
   
   Set the following (get values from Terraform outputs):
   ```bash
   KNOWLEDGE_BASE_ID=<your-kb-id>
   MODEL_ID=anthropic.claude-3-5-sonnet-20240620-v1:0
   S3_BUCKET_NAME=<your-bucket-name>
   AWS_REGION=us-east-1
   ```

2. Enable and start the service:
   ```bash
   sudo systemctl enable bedrock-chatbot
   sudo systemctl start bedrock-chatbot
   sudo systemctl status bedrock-chatbot
   ```

3. Test the application:
   ```bash
   curl http://localhost:8080/api/health  # Direct access
   curl http://localhost/api/health        # Via NGINX on port 80
   ```

## Complete Deployment Workflow

### First Time Deployment

1. **Deploy infrastructure with Terraform:**
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
   
   Note the EC2 instance public IP or hostname from Terraform outputs.

2. **Copy files to EC2** (from your local machine):
   ```bash
   cd ../deployment
   ./copy-to-ec2.sh ubuntu@<ec2-ip-or-hostname> --key ~/.ssh/your-key.pem
   ```

3. **Deploy application on EC2:**
   
   Option A: SSH into EC2 and run:
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<ec2-ip-or-hostname>
   sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh
   ```
   
   Option B: Run directly via SSH:
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<ec2-ip-or-hostname> 'sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh'
   ```

4. **Configure environment variables:**
   ```bash
   sudo nano /etc/bedrock-chatbot/env.conf
   ```
   
   Set required values (get from Terraform outputs):
   - `KNOWLEDGE_BASE_ID`
   - `MODEL_ID`
   - `S3_BUCKET_NAME`
   - `AWS_REGION`

5. **Start the service:**
   ```bash
   sudo systemctl enable bedrock-chatbot
   sudo systemctl start bedrock-chatbot
   sudo systemctl status bedrock-chatbot
   ```

6. **Access the application:**
   - Via NGINX (port 80): `http://<ec2-ip>/`
   - Direct (port 8080): `http://<ec2-ip>:8080/`

### Updating Application Code

To update the application after making code changes:

1. **Copy updated files to EC2:**
   ```bash
   ./copy-to-ec2.sh ubuntu@<ec2-ip-or-hostname> --key ~/.ssh/your-key.pem
   ```

2. **On EC2, stop the service:**
   ```bash
   sudo systemctl stop bedrock-chatbot
   ```

3. **Run deployment script again** (it will update the code):
   ```bash
   sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh
   ```
   
   Note: The script will reinstall dependencies if `requirements.txt` changed.

4. **Start the service:**
   ```bash
   sudo systemctl start bedrock-chatbot
   sudo systemctl status bedrock-chatbot
   ```

## Additional Scripts

### `set-env-vars.sh`

Creates environment variables file. This is automatically called by `deploy-on-ec2.sh`, but you can run it separately if needed.

**Usage:**
```bash
sudo ./set-env-vars.sh
```

### `bedrock-chatbot.service`

Systemd service file template. This is automatically used by `deploy-on-ec2.sh`.

### `nginx-bedrock-chatbot.conf`

NGINX configuration file. This is automatically used by `deploy-on-ec2.sh` if present.

## NGINX Reverse Proxy

The deployment script automatically configures NGINX as a reverse proxy:

- **NGINX listens on port 80** (HTTP)
- **Proxies to Gunicorn on port 8080** (internal)
- **Configuration file**: `/etc/nginx/sites-available/bedrock-chatbot`
- **Enabled site**: `/etc/nginx/sites-enabled/bedrock-chatbot`

### NGINX Management

```bash
# Check NGINX status
sudo systemctl status nginx

# Test NGINX configuration
sudo nginx -t

# Reload NGINX (after configuration changes)
sudo systemctl reload nginx

# View access logs
sudo tail -f /var/log/nginx/bedrock-chatbot-access.log

# View error logs
sudo tail -f /var/log/nginx/bedrock-chatbot-error.log
```

## IAM Role Configuration

The EC2 instance uses an IAM role (configured via Terraform) instead of AWS credentials. The role has the same permissions as the `dev` user:

- `BedrockKnowledgeBaseChatbotPolicy` - Attached to EC2 role
- Access to Bedrock Knowledge Base operations
- Access to Bedrock foundation models
- Access to S3 bucket for documents
- Access to OpenSearch Serverless (if configured)

**No AWS credentials needed!** The EC2 instance automatically uses the IAM role.

## Troubleshooting

### Service won't start

1. Check service status:
   ```bash
   sudo systemctl status bedrock-chatbot
   ```

2. Check logs:
   ```bash
   sudo journalctl -u bedrock-chatbot -n 50
   ```

3. Check environment variables:
   ```bash
   sudo cat /etc/bedrock-chatbot/env.conf
   ```

4. Test application manually:
   ```bash
   cd /app
   source venv/bin/activate
   python app.py
   ```

### Permission errors

1. Check file ownership:
   ```bash
   sudo chown -R ubuntu:ubuntu /app
   sudo chown -R ubuntu:ubuntu /tmp/uploads
   ```

### AWS access errors

1. Verify IAM role is attached:
   ```bash
   curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
   ```

2. Check IAM role permissions in AWS Console

3. Verify environment variables are set correctly

### SSH connection issues

1. Check EC2 instance is running
2. Verify security group allows SSH (port 22) from your IP
3. Verify SSH key is correct
4. Check username (usually `ubuntu` for Ubuntu AMIs)

## Files Created

- `/app/` - Application directory
- `/app/venv/` - Python virtual environment
- `/app/data/` - Database directory
- `/app/logs/` - Log files directory
- `/app/config/` - Configuration files (includes `admin_password.txt`)
- `/tmp/uploads/` - File upload directory
- `/etc/bedrock-chatbot/env.conf` - Environment variables
- `/etc/systemd/system/bedrock-chatbot.service` - Systemd service file
- `/etc/nginx/sites-available/bedrock-chatbot` - NGINX configuration

## Service Management

### Application Service (bedrock-chatbot)

```bash
# Start service
sudo systemctl start bedrock-chatbot

# Stop service
sudo systemctl stop bedrock-chatbot

# Restart service
sudo systemctl restart bedrock-chatbot

# Enable on boot
sudo systemctl enable bedrock-chatbot

# Disable on boot
sudo systemctl disable bedrock-chatbot

# View logs
sudo journalctl -u bedrock-chatbot -f

# View recent logs
sudo journalctl -u bedrock-chatbot -n 100
```

### NGINX Service

```bash
# Start NGINX
sudo systemctl start nginx

# Stop NGINX
sudo systemctl stop nginx

# Restart NGINX
sudo systemctl restart nginx

# Reload NGINX (without downtime)
sudo systemctl reload nginx

# Enable on boot
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

## Notes

- **Port Configuration**:
  - Application runs on port **8080** internally (configurable via `APP_PORT` in env.conf)
  - NGINX listens on port **80** and proxies to port 8080
  - External access should use port 80 (or 443 for HTTPS)
- The service runs as user `ubuntu`
- Logs are written to:
  - Systemd journal: `sudo journalctl -u bedrock-chatbot`
  - Application logs: `/app/logs/` (if file logging enabled)
  - NGINX logs: `/var/log/nginx/bedrock-chatbot-*.log`
- The application uses IAM role for AWS authentication (no credentials needed)
- NGINX handles SSL termination, load balancing, and static file serving
