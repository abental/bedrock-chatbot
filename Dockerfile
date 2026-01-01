# Dockerfile for Bedrock Knowledge Base Chatbot
FROM python:3.14-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Gunicorn for production
RUN pip install --no-cache-dir gunicorn

# Copy application code
COPY src/ .

# Copy config directory (includes admin_password.txt)
COPY config/ ./config/

# Create upload directory
RUN mkdir -p /tmp/uploads && chmod 777 /tmp/uploads

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app /tmp/uploads

# Set secure permissions for admin_password.txt
RUN if [ -f /app/config/admin_password.txt ]; then \
        chmod 600 /app/config/admin_password.txt && \
        chown appuser:appuser /app/config/admin_password.txt; \
    fi

USER appuser

ENV APP_PORT=8080

# Expose port
EXPOSE $APP_PORT

# Health check (using curl if available, otherwise skip)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:$APP_PORT/api/health')" || exit 1

# Run application
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:$APP_PORT", "--timeout", "120", "app:app"]

