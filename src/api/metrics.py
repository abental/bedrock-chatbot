"""
Metrics API routes
"""
from flask import Blueprint, request, jsonify

try:
    from config.logging_config import get_logger
    from db import Database
except ImportError:
    from ..config.logging_config import get_logger
    from ..db import Database
from .utils import admin_required, sanitize_input

bp = Blueprint('metrics', __name__, url_prefix='/api')
logger = get_logger(__name__)

# These will be initialized by app factory
db = None


def init_metrics(database: Database):
    """Initialize metrics routes with dependencies"""
    global db
    db = database
    logger.info("Metrics routes initialized")


@bp.route('/metrics', methods=['GET'])
@admin_required
def get_metrics():
    """Get metrics data"""
    try:
        event_type = sanitize_input(request.args.get('event_type', '')) if request.args.get('event_type') else None
        
        # Validate days parameter
        try:
            days = int(request.args.get('days', 7))
            if days < 1 or days > 365:
                days = 7  # Default to 7 if out of range
        except (ValueError, TypeError):
            days = 7
        
        logger.debug(f"Fetching metrics (days: {days}, event_type: {event_type})")
        summary = db.get_metrics_summary(days=days)
        
        if event_type:
            # Validate event_type
            allowed_types = ['query', 'upload', 'sync', 'error']
            if event_type not in allowed_types:
                logger.warning(f"Invalid event_type: {event_type}, ignoring filter")
                event_type = None
        
        if event_type:
            metrics = db.get_metrics(event_type=event_type)
            logger.debug(f"Retrieved {len(metrics)} metrics for event_type: {event_type}")
        else:
            metrics = db.get_metrics()
            logger.debug(f"Retrieved {len(metrics)} total metrics")
        
        logger.info(f"Metrics retrieved successfully (period: {days} days, total: {summary.get('total_queries', 0)} queries)")
        return jsonify({
            'summary': summary,
            'recent_metrics': metrics[:100],  # Last 100 metrics
            'period_days': days
        })
    except Exception as e:
        logger.error(f"Error getting metrics: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@bp.route('/metrics/summary', methods=['GET'])
@admin_required
def get_metrics_summary():
    """Get metrics summary"""
    try:
        # Validate days parameter
        try:
            days = int(request.args.get('days', 7))
            if days < 1 or days > 365:
                days = 7  # Default to 7 if out of range
        except (ValueError, TypeError):
            days = 7
        
        logger.debug(f"Fetching metrics summary for {days} days")
        summary = db.get_metrics_summary(days=days)
        logger.info(f"Metrics summary retrieved: {summary.get('total_queries', 0)} queries, {summary.get('success_rate', 0):.1f}% success rate")
        return jsonify(summary)
    except Exception as e:
        logger.error(f"Error getting metrics summary: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500

