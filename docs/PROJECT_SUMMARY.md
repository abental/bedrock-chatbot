# Bedrock Knowledge Base Chatbot - Project Summary

## Overview

This project implements a complete Flask-based web application for interacting with AWS Bedrock Knowledge Base, featuring a chatbot interface and admin dashboard for document management. The application uses OpenAI GPT OSS 120B (with Claude Sonnet 3.5 as an alternative) for answer generation.

## Project Structure

```
bedrock-chatbot/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Terraform variables
│   ├── outputs.tf              # Terraform outputs
│   ├── ec2/                     # EC2 module
│   ├── network/                 # VPC and networking module
│   ├── s3/                      # S3 bucket module
│   ├── iam/                     # IAM roles and policies
│   ├── opensearch/              # OpenSearch Serverless module
│   └── bedrock/                 # Bedrock KB module
│
├── src/                         # Flask Application (Modular Architecture)
│   ├── app.py                  # Main Flask application entry point
│   ├── api/                     # REST API routes (Flask Blueprints)
│   │   ├── chatbot.py          # Chatbot endpoints
│   │   ├── history.py          # Search history endpoints
│   │   ├── admin.py            # Admin endpoints
│   │   ├── metrics.py          # Analytics endpoints
│   │   └── health.py           # Health check endpoints
│   ├── db/                      # Database layer
│   │   └── database.py         # SQLite operations
│   ├── kb/                      # Knowledge Base integration
│   │   └── bedrock.py          # AWS Bedrock client
│   ├── config/                  # Configuration management
│   │   ├── manager.py          # Config manager
│   │   └── logging_config.py   # Logging configuration
│   ├── prompt/                  # Prompt engineering
│   │   └── engine.py           # Advanced prompt logic
│   ├── templates/               # HTML Templates
│   │   ├── chatbot.html        # Chatbot UI
│   │   ├── admin_login.html    # Admin login page
│   │   └── admin_dashboard.html # Admin dashboard
│   ├── static/                  # Static Files
│   │   ├── css/
│   │   │   ├── chatbot.css     # Chatbot styles
│   │   │   └── admin.css       # Admin styles
│   │   └── js/
│   │       ├── chatbot.js      # Chatbot frontend logic
│   │       ├── admin.js        # Admin authentication
│   │       └── admin_dashboard.js # Admin dashboard logic
│   ├── logging.ini              # Logging configuration
│   └── requirements.txt         # Python dependencies
│
├── deployment/                  # Deployment scripts and configuration
│   ├── copy-to-ec2.sh          # Copy files to EC2 (runs locally)
│   ├── deploy-on-ec2.sh        # Deploy application (runs on EC2)
│   ├── set-env-vars.sh         # Environment variable setup
│   ├── bedrock-chatbot.service # Systemd service file
│   └── nginx-bedrock-chatbot.conf # NGINX reverse proxy configuration
│
├── config/                      # Configuration files
│   └── admin_password.txt      # Admin password (change in production!)
│
├── docs/                        # Documentation
│   ├── README.md               # Documentation index
│   ├── QUICKSTART.md           # Quick start guide
│   ├── ARCHITECTURE.md         # System architecture
│   ├── ENHANCEMENTS.md         # Feature enhancements
│   └── ...                     # Other documentation
│
├── Dockerfile                   # Docker image definition
├── docker-compose.yaml          # Docker Compose configuration
└── README.md                    # Main project README
```

## Features Implemented

### ✅ Core Requirements

1. **Chatbot Interface**
   - Clean, modern UI with HTML/CSS/JavaScript
   - REST API endpoint `/api/ask` for questions
   - Integration with Bedrock Knowledge Base
   - Displays answers with source citations
   - Session management for conversation context
   - Session-specific localStorage for chat history

2. **Admin UI**
   - Password-protected admin interface with session management
   - Password stored in external file (`config/admin_password.txt`)
   - Document upload to S3 bucket
   - Knowledge Base status monitoring
   - Manual sync triggering
   - Configuration management
   - Metrics dashboard with query statistics

3. **Bedrock Knowledge Base Integration**
   - Automatic document processing:
     - Ingestion from S3
     - Chunking
     - Embedding
     - Indexing in OpenSearch Serverless
   - Query processing with grounded answers
   - Source citation retrieval
   - Uses OpenAI GPT OSS 120B (openai.gpt-oss-120b-1:0) or Claude Sonnet 3.5

### ✅ Infrastructure (Terraform)

1. **VPC and Networking**
   - VPC (10.0.0.0/16) with public and private subnets
   - Public subnet (10.0.1.0/24) for EC2
   - Private subnet (10.0.2.0/24) reserved for future use
   - Internet Gateway
   - Route tables and associations

2. **AWS Services**
   - S3 bucket for knowledge base documents
   - Bedrock Knowledge Base with OpenAI GPT OSS 120B or Claude Sonnet 3.5
   - OpenSearch Serverless collection for vector storage
   - EC2 instance for Flask application (Ubuntu 22.04)

3. **IAM Roles and Permissions**
   - Bedrock Knowledge Base role
   - OpenSearch Serverless role
   - EC2 instance role with necessary permissions
   - Corrected IAM policies with proper Bedrock action prefixes

4. **Security**
   - Security groups for EC2 (ports 22, 80, 443, 8080)
   - Encrypted S3 bucket
   - IAM policies following least privilege
   - Admin authentication with session management
   - HttpOnly cookies for session security

### ✅ Deployment (EC2)

1. **Two-Step Deployment Process**
   - `copy-to-ec2.sh` - Copy files from local to EC2
   - `deploy-on-ec2.sh` - Install and configure on EC2

2. **Production Stack**
   - **Systemd** service for process management
   - **Gunicorn** WSGI server with 4 workers
   - **NGINX** reverse proxy (HTTP/HTTPS → port 8080)
   - **Flask** application on port 8080

3. **Configuration**
   - Environment variables in `/etc/bedrock-chatbot/env.conf`
   - Admin password in `/app/config/admin_password.txt`
   - Application logs via systemd journal

## Technology Stack

- **Backend**: Flask (Python 3.14) with modular package architecture
- **Frontend**: HTML, CSS, JavaScript (vanilla)
- **AI Model**: OpenAI GPT OSS 120B (or Claude Sonnet 3.5)
- **AWS Services**: Bedrock, S3, OpenSearch Serverless, EC2
- **Infrastructure**: Terraform
- **Web Server**: NGINX (reverse proxy) + Gunicorn (WSGI)
- **Process Management**: Systemd
- **Database**: SQLite (for history and metrics)
- **Dependencies**: boto3, flask, gunicorn, werkzeug

## Getting Started

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Get Output Values

```bash
terraform output
```

Note the following values:
- `bedrock_knowledge_base_id`
- `s3_bucket_name`
- `ec2_instance_public_ip` or `ec2_public_dns`
- `opensearch_collection_endpoint`

### 3. Configure Admin Password

```bash
echo "your-secure-password" > config/admin_password.txt
chmod 600 config/admin_password.txt
```

### 4. Deploy Application to EC2

```bash
# From local machine
cd deployment
./copy-to-ec2.sh ubuntu@<ec2-ip> --key ~/.ssh/your-key.pem

# SSH to EC2
ssh ubuntu@<ec2-ip> -i ~/.ssh/your-key.pem

# On EC2
cd /tmp/bedrock-chatbot-deploy/deployment
sudo bash deploy-on-ec2.sh
```

### 5. Verify Deployment

```bash
# Check service status
sudo systemctl status bedrock-chatbot

# View logs
sudo journalctl -u bedrock-chatbot -f

# Test application
curl http://localhost:8080/api/health
```

### 6. Access Application

- **Chatbot**: `http://<ec2-ip>/` or `http://<ec2-dns>/`
- **Admin**: `http://<ec2-ip>/admin` or `http://<ec2-dns>/admin`

## API Endpoints

### Public Endpoints

- `GET /` - Chatbot UI
- `POST /api/ask` - Submit question
- `GET /api/history` - Get search history (all questions or filtered by session)
- `GET /api/history/<query_id>` - Get specific query details
- `GET /api/sources` - Get list of documents in knowledge base
- `GET /api/health` - Health check

### Admin Endpoints (Password Protected)

- `GET /admin` - Admin login page
- `POST /admin/login` - Authenticate
- `POST /admin/logout` - Logout
- `GET /admin/dashboard` - Admin dashboard
- `POST /admin/upload` - Upload document to S3
- `GET /admin/kb/status` - Get knowledge base status
- `POST /admin/kb/sync` - Trigger knowledge base sync
- `GET /admin/config` - Get current configuration
- `GET /api/metrics` - Get analytics metrics
- `GET /api/metrics/summary` - Get metrics summary

## Environment Variables

Configuration is managed through environment variables in `/etc/bedrock-chatbot/env.conf`:

```bash
# Application Configuration
APP_PORT=8080
FLASK_ENV=production
FLASK_DEBUG=False

# AWS Configuration
AWS_REGION=us-east-1

# Application Paths
APP_DIR=/app
VENV_DIR=/app/venv
UPLOAD_FOLDER=/tmp/uploads
DB_PATH=/app/data/chatbot.db
ADMIN_PASSWORD_FILE=/app/config/admin_password.txt

# Flask Secret Key (auto-generated during deployment)
FLASK_SECRET_KEY=<auto-generated>

# Bedrock Configuration (set these from Terraform outputs)
KNOWLEDGE_BASE_ID=<your-kb-id>
MODEL_ID=openai.gpt-oss-120b-1:0
S3_BUCKET_NAME=<your-bucket-name>
```

## Security Considerations

1. **Change default admin password** before production
2. **Set strong FLASK_SECRET_KEY** (auto-generated during deployment)
3. **Enable HTTPS** in production (configure NGINX with SSL certificates)
4. **Restrict SSH access** to EC2 (update security group to specific IPs)
5. **Use IAM roles** instead of access keys (already configured in Terraform)
6. **Regularly rotate** AWS credentials
7. **Monitor logs** via systemd journal and NGINX logs
8. **Review IAM policies** periodically for least privilege

## Knowledge Base Workflow

1. **Upload Document**: Admin uploads document via admin UI
2. **S3 Storage**: Document stored in S3 bucket
3. **Auto-Sync**: Trigger manual sync or wait for auto-sync
4. **Processing**: Bedrock handles:
   - Document ingestion
   - Text chunking
   - Embedding generation (using Titan embeddings)
   - Indexing in OpenSearch Serverless
5. **Query**: Users ask questions via chatbot
6. **Retrieval**: Bedrock retrieves relevant chunks from OpenSearch
7. **Generation**: OpenAI GPT OSS 120B (or Claude Sonnet 3.5) generates grounded answer
8. **Response**: Answer displayed with source citations

## Application Logs

### View Application Logs

```bash
# Follow live logs
sudo journalctl -u bedrock-chatbot -f

# View last 100 lines
sudo journalctl -u bedrock-chatbot -n 100

# View logs with timestamps
sudo journalctl -u bedrock-chatbot -n 50 --no-pager

# Search for specific text
sudo journalctl -u bedrock-chatbot | grep -i "session"
```

### View NGINX Logs

```bash
# Access logs (all HTTP requests)
sudo tail -f /var/log/nginx/bedrock-chatbot-access.log

# Error logs
sudo tail -f /var/log/nginx/bedrock-chatbot-error.log
```

## Testing

### Health Check
```bash
curl http://localhost:8080/api/health
```

### Test Chatbot
```bash
curl -X POST http://localhost:8080/api/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What is AWS Bedrock?"}'
```

### Test Admin Login (locally)
```bash
curl -v -X POST http://localhost:8080/admin/login \
  -H "Content-Type: application/json" \
  -d '{"password":"your-password"}' \
  2>&1 | grep -i "set-cookie"
```

## Deployment Options

1. **EC2 with Systemd** (Recommended for production)
   - Systemd service management
   - Gunicorn WSGI server
   - NGINX reverse proxy
   - Automatic restart on failure

2. **Local Development**
   - Run `python app.py` directly
   - Auto-reload on code changes
   - Port 8080

3. **Docker** (Alternative)
   - Containerized deployment
   - Docker Compose support
   - Good for development and testing

## Documentation

- **Main README**: See `README.md` in project root
- **Quick Start**: See `docs/QUICKSTART.md`
- **Architecture**: See `docs/ARCHITECTURE.md`
- **Terraform**: See `terraform/README.md`
- **Deployment**: See `deployment/README.md`
- **Enhancements**: See `docs/ENHANCEMENTS.md`

## Modular Architecture

The application follows a modular package-based architecture:

- **`api/`** - REST API routes using Flask Blueprints
- **`db/`** - Database layer with SQLite
- **`kb/`** - Bedrock Knowledge Base integration
- **`config/`** - Configuration management and logging
- **`prompt/`** - Advanced prompt engineering
- **`templates/`** - HTML templates
- **`static/`** - CSS and JavaScript files

## Support

For issues:
1. Check application logs: `sudo journalctl -u bedrock-chatbot -f`
2. Check NGINX logs: `/var/log/nginx/bedrock-chatbot-*.log`
3. Review AWS Bedrock documentation
4. Verify IAM permissions with `terraform/iam/`
5. Check security group allows ports 80, 443, 8080

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

The software is provided as-is for educational and demonstration purposes.
