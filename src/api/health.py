"""
Health check API routes
"""
from flask import Blueprint, jsonify

try:
    from config.logging_config import get_logger
except ImportError:
    from ..config.logging_config import get_logger

bp = Blueprint('health', __name__)
logger = get_logger(__name__)

# These will be initialized by app factory
config = None
bedrock_kb = None


def init_health(config_manager, bedrock):
    """Initialize health routes with dependencies"""
    global config, bedrock_kb
    config = config_manager
    bedrock_kb = bedrock
    logger.info("Health check routes initialized")


@bp.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    logger.debug("Health check requested")
    try:
        # Check if Bedrock service is accessible
        status = bedrock_kb.health_check()
        health_status = 'healthy' if status else 'degraded'
        logger.info(f"Health check result: {health_status}")
        return jsonify({
            'status': health_status,
            'service': 'bedrock-knowledge-base',
            'knowledge_base_id': config.get('KNOWLEDGE_BASE_ID')
        }), 200 if status else 503
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 503

