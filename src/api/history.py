"""
Search history API routes
"""
from flask import Blueprint, request, jsonify

try:
    from config.logging_config import get_logger
    from db import Database
    from kb import BedrockKnowledgeBase
except ImportError:
    from ..config.logging_config import get_logger
    from ..db import Database
    from ..kb import BedrockKnowledgeBase

bp = Blueprint('history', __name__, url_prefix='/api')
logger = get_logger(__name__)

# These will be initialized by app factory
db = None
bedrock_kb = None


def init_history(database: Database, bedrock: BedrockKnowledgeBase = None):
    """Initialize history routes with dependencies"""
    global db, bedrock_kb
    db = database
    bedrock_kb = bedrock
    logger.info("History routes initialized")


@bp.route('/history', methods=['GET'])
def get_history():
    """Get search history - returns all questions by default, or filtered by session_id if provided"""
    try:
        # Get session_id from query params, but if empty string or not provided, get all history
        session_id_param = request.args.get('session_id', '')
        session_id = session_id_param if session_id_param and session_id_param.strip() else None
        
        limit = int(request.args.get('limit', 50))
        
        # Validate limit to prevent abuse
        if limit > 1000:
            logger.warning(f"Limit too high ({limit}), capping at 1000")
            limit = 1000
        
        logger.debug(f"Fetching history (session_id: {session_id[:8] if session_id else 'all'}, limit: {limit})")
        history = db.get_search_history(session_id=session_id, limit=limit)
        logger.info(f"Retrieved {len(history)} history records")
        
        return jsonify({
            'history': history,
            'count': len(history)
        })
    except ValueError as e:
        logger.warning(f"Invalid limit parameter: {e}")
        return jsonify({'error': 'Invalid limit parameter'}), 400
    except Exception as e:
        logger.error(f"Error getting history: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@bp.route('/history/<int:query_id>', methods=['GET'])
def get_query_details(query_id):
    """Get details of a specific query"""
    try:
        # Validate query_id
        if query_id <= 0:
            logger.warning(f"Invalid query ID: {query_id}")
            return jsonify({'error': 'Invalid query ID'}), 400
        
        logger.debug(f"Fetching query details for query_id: {query_id}")
        # Use efficient direct query instead of fetching all records
        history = db.get_search_history(query_id=query_id)
        
        if not history or len(history) == 0:
            logger.warning(f"Query not found: {query_id}")
            return jsonify({'error': 'Query not found'}), 404
        
        logger.debug(f"Query details retrieved for query_id: {query_id}")
        return jsonify(history[0])
    except ValueError as e:
        logger.warning(f"Invalid query ID format: {e}")
        return jsonify({'error': 'Invalid query ID format'}), 400
    except Exception as e:
        logger.error(f"Error getting query details: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@bp.route('/sources', methods=['GET'])
def get_sources():
    """Get list of documents in the knowledge base with their names and sizes only"""
    try:
        if not bedrock_kb:
            return jsonify({'error': 'Bedrock Knowledge Base not initialized'}), 500
        
        logger.debug("Fetching documents from knowledge base")
        
        # Get documents from knowledge base
        documents = bedrock_kb.list_documents()
        
        # Format response with only name and size
        formatted_documents = []
        for doc in documents:
            formatted_documents.append({
                'name': doc['name'],
                'size': doc['size']
            })
        
        logger.info(f"Retrieved {len(formatted_documents)} documents from knowledge base")
        
        return jsonify({
            'documents': formatted_documents,
            'count': len(formatted_documents)
        })
    except Exception as e:
        logger.error(f"Error getting documents: {str(e)}", exc_info=True)
        return jsonify({'error': str(e)}), 500

