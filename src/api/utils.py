"""
Utility functions for API routes
"""
import re
from functools import wraps
from flask import jsonify, session, request, redirect, url_for


def admin_required(f):
    """Decorator to require admin authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Try to access session - this forces Flask to load it from the cookie
        admin_logged_in = session.get('admin_logged_in', False)
        
        # If session is empty but we should have a cookie, try to reload session
        # This can happen if the session cookie wasn't read correctly
        if not admin_logged_in:
            # Check if we have a session cookie but session is empty
            cookies = request.cookies
            # Flask's default session cookie name is 'session'
            if 'session' in cookies:
                # We have a cookie but session is empty - might be a session loading issue
                # Try to access session again to force reload
                try:
                    # Force session reload by accessing it
                    _ = dict(session)
                    admin_logged_in = session.get('admin_logged_in', False)
                except Exception:
                    pass
        
        # Debug logging
        import logging
        logger = logging.getLogger(__name__)
        
        if not admin_logged_in:
            # Only log warning for API calls to avoid spam
            is_api = request.path.startswith('/admin/kb/') or request.path.startswith('/admin/config') or request.path.startswith('/api/')
            if is_api:
                logger.warning(f"Admin check FAILED for API: {request.path}")
        
        if not admin_logged_in:
            # Check if this is an API call (JSON request or fetch/XHR request)
            # API calls should return JSON, page requests should redirect
            # Page routes that should redirect: /admin/dashboard
            # API routes that should return JSON: /admin/kb/*, /admin/upload, /admin/config, /api/*
            is_page_route = (
                request.path == '/admin/dashboard' or
                request.path == '/admin'
            )
            
            is_api_call = (
                request.is_json or
                (request.accept_mimetypes.best == 'application/json' and not is_page_route) or
                request.path.startswith('/admin/kb/') or
                request.path.startswith('/admin/upload') or
                request.path.startswith('/admin/config') or
                request.path.startswith('/api/')
            )
            
            logger.debug(f"Admin check failed - is_api_call: {is_api_call}, path: {request.path}, accept: {request.accept_mimetypes.best}")
            
            if is_api_call:
                # Return JSON error for API calls
                return jsonify({'error': 'Admin authentication required'}), 401
            else:
                # Redirect to login for page requests
                logger.debug(f"Redirecting to /admin from {request.path}")
                return redirect('/admin')
        return f(*args, **kwargs)
    return decorated_function


def validate_question(question: str) -> tuple[bool, str]:
    """
    Validate user question input
    
    Returns:
        (is_valid, error_message)
    """
    if not question or not question.strip():
        return False, "Question cannot be empty"
    
    question = question.strip()
    
    # Check length
    if len(question) > 5000:
        return False, "Question is too long (max 5000 characters)"
    
    if len(question) < 3:
        return False, "Question is too short (min 3 characters)"
    
    # Check for potentially malicious patterns
    # Allow most characters but flag suspicious patterns
    suspicious_patterns = [
        r'<script',
        r'javascript:',
        r'on\w+\s*=',
    ]
    
    for pattern in suspicious_patterns:
        if re.search(pattern, question, re.IGNORECASE):
            return False, "Question contains invalid content"
    
    return True, ""


def sanitize_input(text: str, max_length: int = 5000) -> str:
    """Sanitize user input"""
    if not text:
        return ""
    
    # Remove null bytes
    text = text.replace('\x00', '')
    
    # Truncate if too long
    if len(text) > max_length:
        text = text[:max_length]
    
    return text.strip()


def allowed_file(filename, allowed_extensions=None):
    """Check if file extension is allowed"""
    if allowed_extensions is None:
        allowed_extensions = {'pdf', 'txt', 'doc', 'docx', 'md', 'html', 'csv'}
    
    if not filename or '.' not in filename:
        return False
    ext = filename.rsplit('.', 1)[1].lower()
    return ext in allowed_extensions

