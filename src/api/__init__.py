"""
API package for Bedrock Knowledge Base Chatbot REST endpoints
"""
from flask import Flask
from flask_limiter import Limiter

# Import all route modules
from . import chatbot, admin, metrics, history, health


def init_api_routes(config_manager, bedrock_kb, database, upload_folder, max_file_size):
    """Initialize all API routes with their dependencies"""
    # Initialize each route module
    chatbot.init_chatbot(config_manager, bedrock_kb, database)
    admin.init_admin(config_manager, bedrock_kb, upload_folder, max_file_size)
    metrics.init_metrics(database)
    history.init_history(database, bedrock_kb)
    health.init_health(config_manager, bedrock_kb)


def register_blueprints(app: Flask, limiter: Limiter):
    """Register all API blueprints with the Flask app"""
    # Register blueprints
    app.register_blueprint(chatbot.bp)
    app.register_blueprint(admin.bp)
    app.register_blueprint(metrics.bp)
    app.register_blueprint(history.bp)
    app.register_blueprint(health.bp)
    
    # Apply rate limiting to specific routes (after registration)
    limiter.limit("10 per minute")(chatbot.ask_question)
    limiter.limit("5 per minute")(admin.admin_authenticate)
    limiter.limit("20 per hour")(admin.upload_document)

__all__ = ['register_blueprints', 'init_api_routes']

