"""
Flask application for Bedrock Knowledge Base Chatbot
Main application entry point with blueprint-based architecture
"""
import os
import sys
import secrets
from pathlib import Path

# Add src directory to Python path to enable imports when running directly
src_dir = Path(__file__).parent
if str(src_dir) not in sys.path:
    sys.path.insert(0, str(src_dir))

from flask import Flask
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

from config import ConfigManager
from config.logging_config import setup_logging, get_logger
from kb import BedrockKnowledgeBase
from db import Database
from prompt import PromptEngine
from api import register_blueprints, init_api_routes

# Set up logging
logger = get_logger(__name__)
setup_logging()

# Configure upload settings
UPLOAD_FOLDER = '/tmp/uploads'
ALLOWED_EXTENSIONS = {'pdf', 'txt', 'doc', 'docx', 'md', 'html', 'csv'}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB

os.makedirs(UPLOAD_FOLDER, exist_ok=True)


def create_app():
    """Application factory pattern"""
    logger.info("Initializing Flask application")
    app = Flask(__name__)
    
    # CRITICAL: Configure Flask to work behind a reverse proxy (NGINX)
    # This ensures Flask correctly handles X-Forwarded-* headers
    # Only apply ProxyFix if we're actually behind a proxy (check for X-Forwarded-For header)
    # When accessing directly (IP:8080), ProxyFix can cause issues
    try:
        from werkzeug.middleware.proxy_fix import ProxyFix
        # Apply ProxyFix - it will only process X-Forwarded-* headers if they exist
        app.wsgi_app = ProxyFix(
            app.wsgi_app,
            x_for=1,      # Trust 1 proxy (NGINX)
            x_proto=1,    # Trust X-Forwarded-Proto header
            x_host=1,     # Trust X-Forwarded-Host header
            x_port=1,     # Trust X-Forwarded-Port header
            x_prefix=1    # Trust X-Forwarded-Prefix header
        )
        logger.info("ProxyFix middleware configured for reverse proxy support")
    except ImportError:
        logger.warning("ProxyFix not available - install werkzeug>=2.0.0")
    
    # Secure secret key generation - use environment variable or generate one
    secret_key = os.getenv('FLASK_SECRET_KEY')
    if not secret_key:
        # Generate a secure random key for development (warn in production)
        secret_key = secrets.token_hex(32)
        if os.getenv('FLASK_ENV') == 'production':
            logger.warning("WARNING: Using auto-generated secret key in production! Set FLASK_SECRET_KEY environment variable.")
        else:
            logger.info("Generated development secret key")
    else:
        logger.info("Using secret key from environment variable")
    app.secret_key = secret_key
    
    # CRITICAL: Verify session interface is properly initialized
    # Flask uses SecureCookieSessionInterface by default
    from flask.sessions import SecureCookieSessionInterface
    if not isinstance(app.session_interface, SecureCookieSessionInterface):
        logger.warning(f"Unexpected session interface type: {type(app.session_interface).__name__}")
    else:
        logger.debug(f"Session interface initialized: {type(app.session_interface).__name__}")
        logger.debug(f"Session cookie name: {app.session_interface.get_cookie_name(app)}")
    
    # Configure Flask settings
    app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
    app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE
    logger.debug(f"Upload folder: {UPLOAD_FOLDER}, Max file size: {MAX_FILE_SIZE / (1024*1024)}MB")
    
    # Configure session settings - CRITICAL for working behind NGINX and direct access
    app.config['PERMANENT_SESSION_LIFETIME'] = 3600  # 1 hour
    app.config['SESSION_COOKIE_SECURE'] = False  # Must be False for HTTP
    app.config['SESSION_COOKIE_NAME'] = 'session'  # Use Flask's default name
    app.config['SESSION_COOKIE_PATH'] = '/'  # Root path - works everywhere
    app.config['SESSION_COOKIE_DOMAIN'] = None  # Don't set domain - works for IP and domain
    app.config['SESSION_COOKIE_HTTPONLY'] = True  # Prevent XSS
    app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'  # Allow same-site requests
    # Ensure session cookie is always set (even for IP addresses)
    logger.debug(f"Session configured (name: {app.config['SESSION_COOKIE_NAME']}, secure: {app.config['SESSION_COOKIE_SECURE']}, samesite: {app.config['SESSION_COOKIE_SAMESITE']}, domain: {app.config['SESSION_COOKIE_DOMAIN']})")
    
    # Initialize rate limiter
    limiter = Limiter(
        app=app,
        key_func=get_remote_address,
        default_limits=["200 per day", "50 per hour"],
        storage_uri="memory://"
    )
    logger.info("Rate limiter initialized")
    
    # Initialize configuration and services
    logger.info("Initializing configuration and services")
    config = ConfigManager()
    try:
        config.validate()
        logger.info("Configuration validated successfully")
    except ValueError as e:
        logger.error(f"Configuration validation failed: {e}")
        raise
    
    prompt_engine = PromptEngine(config)
    logger.info("Prompt engine initialized")
    
    bedrock_kb = BedrockKnowledgeBase(config, prompt_engine=prompt_engine)
    logger.info(f"Bedrock Knowledge Base initialized (KB ID: {config.get('KNOWLEDGE_BASE_ID')})")
    
    db = Database()
    logger.info("Database initialized")
    
    # Initialize API routes with dependencies
    logger.info("Initializing API routes")
    init_api_routes(config, bedrock_kb, db, UPLOAD_FOLDER, MAX_FILE_SIZE)
    
    # Register blueprints
    logger.info("Registering blueprints")
    register_blueprints(app, limiter)
    
    # Ensure sessions are saved after each request
    @app.after_request
    def save_session(response):
        """Ensure session is saved after each request"""
        from flask import session
        # Force session to be saved if it was modified
        if session.modified:
            session.permanent = True
            
            # CRITICAL: Flask's session interface saves the cookie when response is finalized
            # Check if Set-Cookie header is present
            set_cookie_headers = [h for h in response.headers if h[0].lower() == 'set-cookie']
            session_cookie_found = False
            for header in set_cookie_headers:
                if 'session=' in header[1].lower():
                    session_cookie_found = True
                    logger.debug(f"Session cookie being set: {header[1][:150]}...")
                    break
            
            if not session_cookie_found:
                # Session was modified but cookie not set - try to save it
                logger.warning("Session modified but no session cookie found - attempting to save")
                try:
                    session_interface = app.session_interface
                    if session_interface:
                        # Manually save the session
                        session_interface.save_session(app, session, response)
                        logger.info("Manually triggered session save in after_request")
                        
                        # Check again
                        set_cookie_headers_after = [h for h in response.headers if h[0].lower() == 'set-cookie']
                        for header in set_cookie_headers_after:
                            if 'session=' in header[1].lower():
                                logger.info("Session cookie now present after manual save")
                                break
                        else:
                            logger.error("CRITICAL: Session save called but still no cookie in response!")
                            logger.error(f"Session state - modified: {session.modified}, permanent: {session.permanent}")
                            logger.error(f"Session keys: {list(session.keys())}")
                            logger.error(f"Session interface type: {type(session_interface).__name__}")
                    else:
                        logger.error("No session interface available!")
                except Exception as e:
                    logger.error(f"Failed to manually save session: {e}", exc_info=True)
        return response
    
    logger.info("Application initialization complete")
    return app


# Create the app instance
app = create_app()


if __name__ == '__main__':
    # Development server - DO NOT USE IN PRODUCTION
    # Use Gunicorn or another WSGI server for production
    debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    port = int(os.getenv('APP_PORT', 8080))
    
    if debug_mode and os.getenv('FLASK_ENV') == 'production':
        logger.warning("WARNING: Debug mode is enabled in production! This is a security risk.")
    
    logger.info(f"Starting Flask development server on port {port} (debug={debug_mode})")
    logger.warning("Development server should not be used in production. Use Gunicorn or another WSGI server.")
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug_mode
    )
