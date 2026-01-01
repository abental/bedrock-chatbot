# Bedrock Knowledge Base Chatbot

A Flask-based web application for interacting with AWS Bedrock Knowledge Base, featuring a chatbot interface, admin dashboard, and advanced prompt engineering. Uses OpenAI GPT OSS 120B (or Claude Sonnet 3.5) for answer generation.

## Quick Start

1. **Project Overview**: See [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md) for complete project details
2. **System Architecture**: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for architecture documentation
3. **Deploy Infrastructure**: See [terraform/README.md](terraform/README.md) for AWS setup with Terraform
4. **Deploy Application**: See [deployment/README.md](deployment/README.md) for EC2 deployment instructions
5. **View Interactive Diagrams**: Open [docs/architecture.html](docs/architecture.html) in your browser

## Project Structure

```
bedrock-chatbot/
├── docs/                              # Documentation
│   ├── PROJECT_SUMMARY.md            # Complete project overview
│   ├── ARCHITECTURE.md               # System architecture
│   ├── ARCHITECTURE_DIAGRAM.md       # Mermaid diagrams
│   ├── architecture.html             # Interactive diagrams
│   ├── ENHANCEMENTS.md               # Feature enhancements
│   ├── IAM_POLICY_SETUP.md          # IAM policy guide
│   ├── TERRAFORM_COMMANDS.md         # Terraform reference
│   ├── GUNICORN_VS_FLASK_DEV_SERVER.md  # Deployment guide
│   └── LOGGING_CONFIG.md             # Logging configuration
│
├── src/                               # Flask application (modular architecture)
│   ├── app.py                        # Main application entry point
│   ├── api/                          # REST API routes (Flask Blueprints)
│   │   ├── chatbot.py               # Chatbot endpoints
│   │   ├── history.py               # Search history endpoints
│   │   ├── admin.py                 # Admin endpoints
│   │   ├── metrics.py               # Analytics endpoints
│   │   └── health.py                # Health check endpoints
│   ├── db/                           # Database layer
│   │   └── database.py              # SQLite operations
│   ├── kb/                           # Knowledge Base integration
│   │   └── bedrock.py               # AWS Bedrock client
│   ├── config/                       # Configuration management
│   │   ├── manager.py               # Config manager
│   │   └── logging_config.py        # Logging configuration
│   ├── prompt/                       # Prompt engineering
│   │   └── engine.py                # Advanced prompt logic
│   ├── templates/                    # HTML templates
│   │   ├── chatbot.html             # Chatbot UI
│   │   ├── admin_login.html         # Admin login page
│   │   └── admin_dashboard.html     # Admin dashboard
│   ├── static/                       # Static files
│   │   ├── css/                     # Stylesheets
│   │   └── js/                      # JavaScript
│   ├── logging.ini                   # Logging configuration
│   └── requirements.txt              # Python dependencies
│
├── deployment/                        # Deployment scripts
│   ├── copy-to-ec2.sh                # Copy files to EC2 (runs locally)
│   ├── deploy-on-ec2.sh              # Deploy application (runs on EC2)
│   ├── set-env-vars.sh               # Environment variable setup
│   ├── bedrock-chatbot.service       # Systemd service file
│   ├── nginx-bedrock-chatbot.conf    # NGINX reverse proxy config
│   └── README.md                     # Deployment documentation
│
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                       # Main Terraform configuration
│   ├── variables.tf                  # Variables
│   ├── outputs.tf                    # Outputs
│   ├── ec2/                          # EC2 module
│   ├── network/                      # VPC and networking
│   ├── s3/                           # S3 bucket
│   ├── iam/                          # IAM roles and policies
│   ├── opensearch/                   # OpenSearch Serverless
│   ├── bedrock/                      # Bedrock Knowledge Base
│   └── README.md                     # Terraform documentation
│
├── config/                            # Configuration files
│   └── admin_password.txt            # Admin password (change in production!)
│
├── Dockerfile                         # Docker image definition
├── docker-compose.yaml                # Docker Compose configuration
├── Makefile                           # Docker convenience commands
└── README.md                          # This file
```

## Features

- 🤖 **Chatbot Interface** - Clean UI for querying the Knowledge Base
- 🔐 **Admin Dashboard** - Password-protected document management with session authentication
- 📦 **S3 Integration** - Automatic document upload and processing
- 🔍 **Bedrock Knowledge Base** - Vector search with grounded answers
- 🧠 **OpenAI GPT OSS 120B** - Primary AI model (or Claude Sonnet 3.5 as alternative)
- 📊 **Metrics Dashboard** - Track queries, performance, and usage statistics
- 🐳 **Docker Support** - Easy containerized deployment
- ☁️ **AWS Infrastructure** - Complete Terraform setup with modular architecture
- 🌐 **Production Stack** - NGINX + Gunicorn + Systemd for robust deployment

## Requirements

- Python 3.14
- AWS Account with Bedrock access (OpenAI GPT OSS 120B or Claude Sonnet 3.5)
- Docker (optional, for containerized deployment)
- Terraform >= 1.0 (for infrastructure deployment)
- SSH key pair for EC2 access

## Getting Started

### Local Development

```bash
cd src
python3.14 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

### Docker Deployment

```bash
# From project root
make build
make up
```

### AWS Deployment

1. **Deploy infrastructure:**
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
   
   Note the EC2 instance public IP or hostname from Terraform outputs.

2. **Copy files to EC2:**
   ```bash
   cd ../deployment
   ./copy-to-ec2.sh ubuntu@<ec2-ip-or-hostname> --key ~/.ssh/your-key.pem
   ```
   
   This copies `src/`, `config/`, and `deployment/` directories to the EC2 instance.

3. **Deploy application on EC2:**
   
   SSH into the EC2 instance:
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<ec2-ip-or-hostname>
   ```
   
   Run the deployment script:
   ```bash
   sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh
   ```
   
   Or run it directly via SSH:
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<ec2-ip-or-hostname> 'sudo /tmp/bedrock-chatbot-deploy/deployment/deploy-on-ec2.sh'
   ```

4. **Configure environment variables:**
   ```bash
   sudo nano /etc/bedrock-chatbot/env.conf
   ```
   
   Set the required values (get from Terraform outputs):
   - `KNOWLEDGE_BASE_ID=<your-kb-id>`
   - `MODEL_ID=openai.gpt-oss-120b-1:0` (or `anthropic.claude-3-5-sonnet-20241022-v2:0`)
   - `S3_BUCKET_NAME=<your-bucket-name>`

5. **Restart the service:**
   ```bash
   sudo systemctl restart bedrock-chatbot
   sudo systemctl status bedrock-chatbot
   ```

6. **View logs:**
   ```bash
   sudo journalctl -u bedrock-chatbot -f
   ```

## Documentation

All documentation is in the `docs/` directory:

### Core Documentation
- **[Project Summary](docs/PROJECT_SUMMARY.md)** - Complete project overview, features, and getting started
- **[System Architecture](docs/ARCHITECTURE.md)** - Architecture documentation with technology stack
- **[Architecture Diagrams](docs/ARCHITECTURE_DIAGRAM.md)** - Mermaid diagrams for system components
- **[Interactive Diagrams](docs/architecture.html)** - Visual system architecture (open in browser)

### Feature Documentation
- **[Enhancements](docs/ENHANCEMENTS.md)** - Feature enhancements (history, metrics, prompts, admin auth)
- **[Logging Configuration](docs/LOGGING_CONFIG.md)** - Centralized logging setup

### Deployment & Infrastructure
- **[Terraform Commands](docs/TERRAFORM_COMMANDS.md)** - Terraform reference and commands
- **[IAM Policy Setup](docs/IAM_POLICY_SETUP.md)** - IAM roles and permissions guide
- **[Gunicorn vs Flask Dev Server](docs/GUNICORN_VS_FLASK_DEV_SERVER.md)** - Production deployment guide
- **[Deployment Guide](deployment/README.md)** - EC2 deployment instructions
- **[Terraform Guide](terraform/README.md)** - Infrastructure setup with Terraform

## Key Technologies

- **Backend**: Flask (Python 3.14) with modular package architecture
- **AI Model**: OpenAI GPT OSS 120B (openai.gpt-oss-120b-1:0) or Claude Sonnet 3.5
- **Vector Store**: OpenSearch Serverless
- **Web Server**: NGINX (reverse proxy) + Gunicorn (WSGI server)
- **Process Management**: Systemd service
- **Infrastructure**: Terraform (modular architecture)
- **Database**: SQLite (for history and metrics)

## Application URLs

After deployment:
- **Chatbot**: `http://<ec2-ip>/` or `http://<ec2-dns>/`
- **Admin Dashboard**: `http://<ec2-ip>/admin` or `http://<ec2-dns>/admin`
- **Health Check**: `http://<ec2-ip>/api/health`

## Troubleshooting

### View Application Logs
```bash
# Follow live logs
sudo journalctl -u bedrock-chatbot -f

# View last 100 lines
sudo journalctl -u bedrock-chatbot -n 100
```

### View NGINX Logs
```bash
# Access logs
sudo tail -f /var/log/nginx/bedrock-chatbot-access.log

# Error logs
sudo tail -f /var/log/nginx/bedrock-chatbot-error.log
```

### Check Service Status
```bash
sudo systemctl status bedrock-chatbot
```

### Restart Service
```bash
sudo systemctl restart bedrock-chatbot
```

## Contributing

This project follows a modular architecture with Flask Blueprints. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.





