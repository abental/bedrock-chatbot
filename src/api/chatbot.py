"""
Chatbot API routes
"""
import os
import time
from flask import Blueprint, render_template, request, jsonify, session

try:
    from config import ConfigManager
    from config.logging_config import get_logger
    from kb import BedrockKnowledgeBase
    from db import Database
    from prompt import PromptEngine
except ImportError:
    from ..config import ConfigManager
    from ..config.logging_config import get_logger
    from ..kb import BedrockKnowledgeBase
    from ..db import Database
    from ..prompt import PromptEngine
from .utils import validate_question, sanitize_input

bp = Blueprint('chatbot', __name__)
logger = get_logger(__name__)

# These will be initialized by app factory
config = None
bedrock_kb = None
db = None


def init_chatbot(config_manager: ConfigManager, bedrock: BedrockKnowledgeBase, database: Database):
    """Initialize chatbot routes with dependencies"""
    global config, bedrock_kb, db
    config = config_manager
    bedrock_kb = bedrock
    db = database
    logger.info("Chatbot routes initialized")


@bp.route('/')
def index():
    """Main chatbot interface"""
    logger.debug("Rendering chatbot interface")
    return render_template('chatbot.html')


@bp.route('/api/ask', methods=['POST'])
def ask_question():
    """
    Chatbot endpoint to query the Knowledge Base with history and metrics
    """
    start_time = time.time()
    client_ip = request.remote_addr
    
    try:
        data = request.get_json()
        if not data:
            logger.warning(f"Invalid request from {client_ip}: Missing JSON body")
            return jsonify({'error': 'Invalid request: JSON body required'}), 400
        
        question = sanitize_input(data.get('question', ''))
        session_id = sanitize_input(data.get('session_id', '')) or session.get('session_id')
        query_type = sanitize_input(data.get('query_type', '')) if data.get('query_type') else None
        use_advanced_prompts = data.get('use_advanced_prompts', True)
        
        logger.info(f"Query received from {client_ip} (session: {session_id[:8] if session_id else 'new'}): {question[:100]}")
        
        # Validate question
        is_valid, error_msg = validate_question(question)
        if not is_valid:
            logger.warning(f"Invalid question from {client_ip}: {error_msg}")
            return jsonify({'error': error_msg}), 400
        
        # Get conversation history for context
        conversation_history = []
        if session_id:
            history = db.get_session_history(session_id)
            conversation_history = [
                {'question': h['question'], 'answer': h['answer']} 
                for h in history[-5:]  # Last 5 exchanges
            ]
            logger.debug(f"Loaded {len(conversation_history)} previous exchanges for session {session_id[:8]}")
        
        # Query the Knowledge Base
        logger.debug(f"Querying Knowledge Base (type: {query_type or 'auto-detect'}, advanced_prompts: {use_advanced_prompts})")
        response = bedrock_kb.query(
            question=question,
            session_id=session_id,
            conversation_history=conversation_history,
            query_type=query_type,
            use_advanced_prompts=use_advanced_prompts
        )
        
        # Store session ID
        session['session_id'] = response.get('session_id')
        session_id = response.get('session_id')
        
        response_time = response.get('response_time_ms', 0)
        sources_count = len(response.get('sources', []))
        
        logger.info(f"Query successful (session: {session_id[:8]}, response_time: {response_time}ms, sources: {sources_count})")
        
        # Save to search history
        query_id = db.save_query(
            session_id=session_id,
            question=question,
            answer=response.get('answer', ''),
            sources=response.get('sources', []),
            model_id=config.get('MODEL_ID'),
            kb_id=config.get('KNOWLEDGE_BASE_ID'),
            response_time_ms=response_time
        )
        logger.debug(f"Query saved to history (query_id: {query_id})")
        
        # Save metric
        duration_ms = int((time.time() - start_time) * 1000)
        db.save_metric(
            event_type='query',
            event_data={
                'question': question,
                'query_id': query_id,
                'session_id': session_id,
                'sources_count': sources_count,
                'query_type': response.get('query_type', 'general')
            },
            duration_ms=duration_ms,
            success=True
        )
        
        return jsonify({
            'answer': response.get('answer', 'No answer found'),
            'sources': response.get('sources', []),
            'session_id': session_id,
            'query_id': query_id,
            'response_time_ms': response_time,
            'query_type': response.get('query_type', 'general'),
            'enhanced_question': response.get('enhanced_question'),
            'metadata': response.get('metadata', {})
        })
    
    except Exception as e:
        logger.error(f"Error querying knowledge base from {client_ip}: {str(e)}", exc_info=True)
        
        # Save error metric
        duration_ms = int((time.time() - start_time) * 1000)
        db.save_metric(
            event_type='query',
            event_data={'error': str(e)},
            duration_ms=duration_ms,
            success=False,
            error_message=str(e)
        )
        
        return jsonify({'error': f'Failed to process question: {str(e)}'}), 500

