"""
Configuration management for the Flask application
"""
import os
import re
from dotenv import load_dotenv

try:
    from config.logging_config import get_logger
except ImportError:
    from .logging_config import get_logger

# Load environment variables from .env file
load_dotenv()

logger = get_logger(__name__)


class ConfigManager:
    """Manages application configuration from environment variables"""
    
    def __init__(self):
        """Initialize configuration with defaults"""
        logger.debug("Initializing ConfigManager")

        self.config = {
            'AWS_REGION': os.getenv('AWS_REGION', 'us-east-1'),
            'KNOWLEDGE_BASE_ID': os.getenv('KNOWLEDGE_BASE_ID', 'R6TD9J5RHA'),
            'DATA_SOURCE_ID': os.getenv('DATA_SOURCE_ID', 'DGL4BJP0EC'),
            # Model                           | Product ID
            # ------------------------------------------------------
            # Anthropic Claude Sonnet 4.5       prod-mxcfnwvpd6kb4
            # Anthropic Claude 3.5 Sonnet v2	prod-cx7ovbu5wex7g
            # 'anthropic.claude-3-5-sonnet-20241022-v2:0'), Anthropic models have inferenceTypesSupported: ["INFERENCE_PROFILE"]
            #                                               and thus you need to add inference related permissions to the user/IAM role under which this application runs!
            # openai.gpt-oss-120b-1:0 - OpenAI OOS GPT model has inferenceTypesSupported: ["ON_DEMAND"]
            # in order to understand what inference types are supported model
            # for more details run:
            #       aws bedrock list-foundation-models --region us-east-1 > foundation-models.txt
            #       aws bedrock list-inference-profiles --region us-east-1 > inference-profiles.txt
            #
            'MODEL_ID': os.getenv('MODEL_ID', 'openai.gpt-oss-120b-1:0'),
            'S3_BUCKET_NAME': os.getenv('S3_BUCKET_NAME', 'abt-bedrock-kb-store'),
            'MAX_TOKENS': int(os.getenv('MAX_TOKENS', 1000)),
            'TEMPERATURE': float(os.getenv('TEMPERATURE', 0.7)),
            'ADMIN_PASSWORD_FILE': os.getenv('ADMIN_PASSWORD_FILE', 'config/admin_password.txt'),
            'FLASK_SECRET_KEY': os.getenv('FLASK_SECRET_KEY', 'dev-secret-key-change-in-production'),
            'FLASK_DEBUG': os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
        }
        logger.info(f"Configuration loaded (region: {self.config['AWS_REGION']}, KB ID: {self.config['KNOWLEDGE_BASE_ID']})")
    
    def get(self, key, default=None):
        """Get configuration value"""
        return self.config.get(key, default)
    
    def set(self, key, value):
        """Set configuration value"""
        self.config[key] = value
    
    def validate(self):
        """Validate required configuration"""
        logger.debug("Validating configuration")
        required = ['KNOWLEDGE_BASE_ID', 'S3_BUCKET_NAME']
        missing = [key for key in required if not self.config.get(key)]
        
        if missing:
            logger.error(f"Missing required configuration: {', '.join(missing)}")
            raise ValueError(f"Missing required configuration: {', '.join(missing)}")
        
        # Validate AWS region format
        region = self.config.get('AWS_REGION', '')
        if region and not re.match(r'^[a-z0-9-]+$', region):
            logger.error(f"Invalid AWS region format: {region}")
            raise ValueError(f"Invalid AWS region format: {region}")
        
        # Validate numeric values
        max_tokens = self.config.get('MAX_TOKENS', 1000)
        if not isinstance(max_tokens, int) or max_tokens < 1 or max_tokens > 100000:
            logger.error(f"Invalid MAX_TOKENS: {max_tokens}")
            raise ValueError(f"MAX_TOKENS must be between 1 and 100000, got: {max_tokens}")
        
        temperature = self.config.get('TEMPERATURE', 0.7)
        if not isinstance(temperature, (int, float)) or temperature < 0 or temperature > 2:
            logger.error(f"Invalid TEMPERATURE: {temperature}")
            raise ValueError(f"TEMPERATURE must be between 0 and 2, got: {temperature}")
        
        logger.info("Configuration validation passed")
        return True

