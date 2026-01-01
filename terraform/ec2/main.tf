# ============================================================================
# EC2 Instance for Flask Application
# ============================================================================

# Security Group for EC2 Instance
resource "aws_security_group" "flask_app" {
  name        = "${var.project_name}-flask-app-sg"
  description = "Security group for Flask chatbot application"
  vpc_id      = var.vpc_id

  # Allow HTTP from anywhere
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS from anywhere
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Flask app port (for direct access)
  ingress {
    description = "Flask App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH from anywhere (restrict in production)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-flask-app-sg"
  }
}

# ============================================================================
# EC2 Instance
# ============================================================================
# Note: IAM Role, policies, and instance profile are created in the IAM module

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# User data script for EC2 initialization (Ubuntu 22.04)
locals {
  user_data = <<-EOF
#!/bin/bash
set -e

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install Python 3.14 dependencies and build tools
# Note: Python 3.14 may need to be installed via pyenv or deadsnakes PPA
sudo apt-get install -y python3 python3-pip python3-venv git build-essential \
  libssl-dev libbz2-dev libffi-dev zlib1g-dev libreadline-dev libsqlite3-dev \
  curl wget software-properties-common

# Create application directory
sudo mkdir -p /opt/bedrock-chatbot
sudo chown ubuntu:ubuntu /opt/bedrock-chatbot

# Install CloudWatch agent (optional)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb || sudo apt-get install -f -y

# Create systemd service directory
sudo mkdir -p /etc/systemd/system

# Install pyenv for Python 3.14 (optional)
# curl https://pyenv.run | bash
# echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
# echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
# echo 'eval "$(pyenv init -)"' >> ~/.bashrc

echo "✅ Ubuntu 22.04 EC2 instance initialized successfully"
echo "📝 Next: Deploy your Flask application to /opt/bedrock-chatbot"
EOF
}

# EC2 Instance
resource "aws_instance" "flask_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.flask_app.id]
  iam_instance_profile   = var.ec2_instance_profile_name
  key_name               = var.ec2_key_pair_name != "" ? var.ec2_key_pair_name : null

  user_data = local.user_data

  # Enable detailed monitoring
  monitoring = true

  # Root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = 25
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-flask-app"
  }
}

