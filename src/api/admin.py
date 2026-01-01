"""
Admin API routes
"""
import os
import time
import secrets
from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for, make_response
from flask.sessions import SecureCookieSessionInterface
from werkzeug.utils import secure_filename

try:
    from config import ConfigManager
    from config.logging_config import get_logger
    from kb import BedrockKnowledgeBase
except ImportError:
    from ..config import ConfigManager
    from ..config.logging_config import get_logger
    from ..kb import BedrockKnowledgeBase
from .utils import admin_required, allowed_file, sanitize_input

bp = Blueprint('admin', __name__, url_prefix='/admin')
logger = get_logger(__name__)

# These will be initialized by app factory
config = None
bedrock_kb = None
UPLOAD_FOLDER = None
MAX_FILE_SIZE = None


def init_admin(config_manager: ConfigManager, bedrock: BedrockKnowledgeBase, upload_folder: str, max_file_size: int):
    """Initialize admin routes with dependencies"""
    global config, bedrock_kb, UPLOAD_FOLDER, MAX_FILE_SIZE
    config = config_manager
    bedrock_kb = bedrock
    UPLOAD_FOLDER = upload_folder
    MAX_FILE_SIZE = max_file_size
    logger.info(f"Admin routes initialized (upload_folder: {upload_folder}, max_size: {max_file_size / (1024*1024)}MB)")


@bp.route('')
def admin_login_page():
    """Admin login page"""
    if session.get('admin_logged_in'):
        return redirect(url_for('admin.admin_dashboard'))
    return render_template('admin_login.html')


@bp.route('/login', methods=['POST'])
def admin_authenticate():
    """Admin authentication"""
    client_ip = request.remote_addr
    logger.info(f"Admin login attempt from {client_ip}")
    
    try:
        data = request.get_json()
        if not data:
            logger.warning(f"Invalid login request from {client_ip}: Missing JSON body")
            return jsonify({'error': 'Invalid request'}), 400
        
        password = data.get('password', '')
        
        # Validate password input
        if not password or len(password) > 1000:
            logger.warning(f"Invalid password format from {client_ip}")
            return jsonify({'error': 'Invalid password'}), 400
        
        # Read password from external file
        password_file = config.get('ADMIN_PASSWORD_FILE', 'config/admin_password.txt')
        
        # Use absolute path or relative to project root
        if not os.path.isabs(password_file):
            # Try relative to src directory first, then project root
            src_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '..', password_file)
            root_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '..', '..', password_file)
            if os.path.exists(src_path):
                password_file = src_path
            elif os.path.exists(root_path):
                password_file = root_path
        
        if not os.path.exists(password_file):
            logger.error(f"Admin password file not found: {password_file}")
            return jsonify({'error': 'Authentication configuration error'}), 500
        
        with open(password_file, 'r') as f:
            stored_password = f.read().strip()
        
        # Use constant-time comparison to prevent timing attacks
        if secrets.compare_digest(password, stored_password):
            # Set session data - CRITICAL: Do this before creating any response
            session['admin_logged_in'] = True
            session.permanent = True  # Make session persistent
            session.modified = True  # Mark session as modified so Flask saves it
            
            # Force Flask to save the session by accessing the session interface
            # This ensures the session cookie is actually set
            from flask import has_request_context
            if has_request_context():
                # Access session to trigger save
                _ = session.get('admin_logged_in')
            
            logger.info(f"Admin login successful from {client_ip}")
            logger.debug(f"Session keys: {list(session.keys())}, Admin logged in: {session.get('admin_logged_in')}")
            logger.debug(f"Session permanent: {session.permanent}, Session modified: {session.modified}")
            
            # Always return JSON for AJAX requests - session cookie is set in response
            is_ajax = request.is_json or request.accept_mimetypes.best == 'application/json'
            
            dashboard_url = url_for('admin.admin_dashboard')
            
            if is_ajax:
                # AJAX request - return JSON with redirect URL
                # Create response
                response = make_response(jsonify({'success': True, 'redirect': dashboard_url}))
                
                # CRITICAL: Explicitly save session to ensure cookie is set
                # Flask's session interface should save automatically, but we'll do it explicitly
                from flask import current_app
                try:
                    session_interface = current_app.session_interface
                    if session_interface:
                        # Manually save the session to ensure cookie is set
                        # This MUST happen before returning the response
                        session_interface.save_session(current_app, session, response)
                        logger.info("Session explicitly saved via session interface")
                        
                        # Verify cookie was actually set
                        set_cookie_headers = [h for h in response.headers if h[0].lower() == 'set-cookie']
                        session_cookie_set = False
                        for header in set_cookie_headers:
                            if 'session=' in header[1].lower():
                                session_cookie_set = True
                                logger.info(f"Session cookie confirmed in response: {header[1][:100]}...")
                                break
                        
                        if not session_cookie_set:
                            logger.error("CRITICAL: Session save called but no session cookie in response headers!")
                            logger.error(f"All Set-Cookie headers: {[h[1][:50] for h in set_cookie_headers]}")
                            logger.error(f"Session state - modified: {session.modified}, permanent: {session.permanent}")
                            logger.error(f"Session keys: {list(session.keys())}")
                    else:
                        logger.error("No session interface found!")
                except Exception as e:
                    logger.error(f"Error saving session: {e}", exc_info=True)
                
                return response
            else:
                # Form submission - do server-side redirect
                return redirect(dashboard_url)
        else:
            # Add small delay to prevent timing attacks
            time.sleep(0.1)
            logger.warning(f"Admin login failed from {client_ip}: Invalid password")
            return jsonify({'error': 'Invalid password'}), 401
    
    except Exception as e:
        logger.error(f"Admin authentication error from {client_ip}: {str(e)}", exc_info=True)
        return jsonify({'error': 'Authentication failed'}), 500


@bp.route('/logout', methods=['POST'])
def admin_logout():
    """Admin logout"""
    client_ip = request.remote_addr
    logger.info(f"Admin logout from {client_ip}")
    session.pop('admin_logged_in', None)
    return jsonify({'success': True, 'redirect': url_for('admin.admin_login_page')})


@bp.route('/dashboard')
@admin_required
def admin_dashboard():
    """Admin dashboard"""
    logger.debug("Admin dashboard accessed")
    return render_template('admin_dashboard.html')


@bp.route('/upload', methods=['POST'])
@admin_required
def upload_document():
    """
    Upload document to S3 bucket
    """
    client_ip = request.remote_addr
    logger.info(f"File upload request from {client_ip}")
    
    try:
        if 'file' not in request.files:
            logger.warning(f"No file provided in upload request from {client_ip}")
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        
        if file.filename == '':
            logger.warning(f"Empty filename in upload request from {client_ip}")
            return jsonify({'error': 'No file selected'}), 400
        
        original_filename = file.filename
        logger.info(f"Uploading file: {original_filename} from {client_ip}")
        
        # Validate filename
        if not file.filename or len(file.filename) > 255:
            logger.warning(f"Invalid filename from {client_ip}: {file.filename}")
            return jsonify({'error': 'Invalid filename'}), 400
        
        if not allowed_file(file.filename):
            logger.warning(f"File type not allowed from {client_ip}: {file.filename}")
            return jsonify({
                'error': f'File type not allowed. Allowed types: pdf, txt, doc, docx, md, html, csv'
            }), 400
        
        # Check file size
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)
        
        logger.debug(f"File size: {file_size / (1024*1024):.2f}MB")
        
        if file_size > MAX_FILE_SIZE:
            logger.warning(f"File too large from {client_ip}: {file_size / (1024*1024):.2f}MB")
            return jsonify({'error': f'File too large. Maximum size: {MAX_FILE_SIZE / (1024*1024)}MB'}), 400
        
        # Secure filename and save temporarily
        filename = secure_filename(file.filename)
        if not filename:
            logger.warning(f"Filename sanitization failed from {client_ip}: {file.filename}")
            return jsonify({'error': 'Invalid filename after sanitization'}), 400
        
        # Add timestamp to prevent overwrites
        timestamp = str(int(time.time()))
        name, ext = os.path.splitext(filename)
        filename = f"{name}_{timestamp}{ext}"
        
        temp_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(temp_path)
        logger.debug(f"File saved temporarily: {temp_path}")
        
        # Upload to S3
        s3_key = f"documents/{filename}"
        logger.info(f"Uploading to S3: {s3_key}")
        success = bedrock_kb.upload_to_s3(temp_path, s3_key)
        
        # Clean up temp file
        os.remove(temp_path)
        logger.debug(f"Temporary file removed: {temp_path}")
        
        if success:
            logger.info(f"File uploaded successfully: {s3_key} (original: {original_filename})")
            return jsonify({
                'success': True,
                'message': f'File {filename} uploaded successfully',
                's3_key': s3_key
            })
        else:
            logger.error(f"Failed to upload file to S3: {s3_key}")
            return jsonify({'error': 'Failed to upload file to S3'}), 500
    
    except Exception as e:
        logger.error(f"Upload error from {client_ip}: {str(e)}", exc_info=True)
        return jsonify({'error': f'Upload failed: {str(e)}'}), 500


@bp.route('/kb/status', methods=['GET'])
@admin_required
def kb_status():
    """Get Knowledge Base status and statistics"""
    logger.debug("KB status requested")
    try:
        status = bedrock_kb.get_status()
        logger.info(f"KB status retrieved: {status.get('status')}, {status.get('s3_documents')} documents")
        return jsonify(status)
    except Exception as e:
        logger.error(f"KB status error: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@bp.route('/kb/sync', methods=['POST'])
@admin_required
def trigger_sync():
    """Manually trigger Knowledge Base sync"""
    logger.info("KB sync triggered manually")
    try:
        data_source_id = config.get('DATA_SOURCE_ID')
        if not data_source_id:
            logger.warning("Data source ID not configured")
            return jsonify({'error': 'Data source ID not configured'}), 400
        
        logger.info(f"Starting ingestion job for data source: {data_source_id}")
        result = bedrock_kb.start_ingestion_job(data_source_id)
        job_id = result.get('ingestionJobId')
        logger.info(f"Sync job started successfully: {job_id}")
        return jsonify({
            'success': True,
            'message': 'Sync job started',
            'job_id': job_id
        })
    except Exception as e:
        logger.error(f"Sync error: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@bp.route('/config', methods=['GET', 'POST'])
@admin_required
def manage_config():
    """Get or update chatbot configuration"""
    if request.method == 'GET':
        logger.debug("Configuration requested")
        return jsonify({
            'knowledge_base_id': config.get('KNOWLEDGE_BASE_ID'),
            'model_id': config.get('MODEL_ID'),
            'region': config.get('AWS_REGION'),
            'max_tokens': config.get('MAX_TOKENS', 1000),
            'temperature': config.get('TEMPERATURE', 0.7)
        })
    
    elif request.method == 'POST':
        # Update configuration (in memory only - for demo)
        # In production, save to database or config file
        data = request.get_json()
        logger.info(f"Configuration update requested: {list(data.keys()) if data else 'empty'}")
        return jsonify({
            'success': True,
            'message': 'Configuration updated (in-memory only)',
            'config': data
        })

