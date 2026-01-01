"""
Database models and utilities for search history and metrics
"""
import sqlite3
import json
from datetime import datetime
from typing import List, Dict, Optional
from contextlib import contextmanager
import os

try:
    from config.logging_config import get_logger
except ImportError:
    from ..config.logging_config import get_logger

logger = get_logger(__name__)


class Database:
    """SQLite database for storing search history and metrics"""
    
    def __init__(self, db_path: str = 'data/chatbot.db'):
        """
        Initialize database connection
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = db_path
        logger.info(f"Initializing database: {db_path}")
        
        # Create directory if needed (handle case where db_path is just filename)
        db_dir = os.path.dirname(db_path)
        if db_dir:
            os.makedirs(db_dir, exist_ok=True)
            logger.debug(f"Database directory created/verified: {db_dir}")
        
        self._init_database()
        logger.info("Database initialization complete")
    
    def _init_database(self):
        """Initialize database tables from SQL schema file"""
        # Look for schema file relative to this package
        schema_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'db-schema.sql')
        
        if not os.path.exists(schema_file):
            logger.error(f"SQL schema file not found: {schema_file}")
            raise FileNotFoundError(f"SQL schema file not found: {schema_file}")
        
        logger.debug(f"Loading schema from: {schema_file}")
        with open(schema_file, 'r') as f:
            schema_sql = f.read()
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Execute all SQL commands from the schema file
            # Split by semicolon and execute each statement
            statements = [stmt.strip() for stmt in schema_sql.split(';') if stmt.strip()]
            logger.debug(f"Executing {len(statements)} SQL statements from schema")
            
            for statement in statements:
                if statement:
                    cursor.execute(statement)
            
            conn.commit()
            logger.debug("Database schema initialized successfully")
    
    @contextmanager
    def _get_connection(self):
        """Get database connection with context manager"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()
    
    def save_query(self, session_id: str, question: str, answer: str, 
                   sources: List[Dict], model_id: str, kb_id: str, 
                   response_time_ms: int) -> int:
        """
        Save a query to search history
        
        Returns:
            Query ID
        """
        logger.debug(f"Saving query to history (session: {session_id[:8] if session_id else 'N/A'}, response_time: {response_time_ms}ms)")
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO search_history 
                (session_id, question, answer, sources, model_id, kb_id, response_time_ms)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                session_id,
                question,
                answer,
                json.dumps(sources),
                model_id,
                kb_id,
                response_time_ms
            ))
            query_id = cursor.lastrowid
            
            # Update session
            cursor.execute('''
                INSERT OR REPLACE INTO sessions (session_id, last_activity, query_count)
                VALUES (
                    ?,
                    CURRENT_TIMESTAMP,
                    COALESCE((SELECT query_count FROM sessions WHERE session_id = ?), 0) + 1
                )
            ''', (session_id, session_id))
            
            conn.commit()
            logger.debug(f"Query saved with ID: {query_id}")
            return query_id
    
    def get_search_history(self, session_id: Optional[str] = None, 
                          limit: int = 50, query_id: Optional[int] = None) -> List[Dict]:
        """
        Get search history
        
        Args:
            session_id: Optional session ID to filter by
            limit: Maximum number of results
            query_id: Optional specific query ID to retrieve
        
        Returns:
            List of query records
        """
        if query_id:
            logger.debug(f"Fetching query by ID: {query_id}")
        elif session_id:
            logger.debug(f"Fetching history for session: {session_id[:8]} (limit: {limit})")
        else:
            logger.debug(f"Fetching all history (limit: {limit})")
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            if query_id:
                cursor.execute('''
                    SELECT * FROM search_history
                    WHERE id = ?
                ''', (query_id,))
            elif session_id:
                cursor.execute('''
                    SELECT * FROM search_history
                    WHERE session_id = ?
                    ORDER BY created_at DESC
                    LIMIT ?
                ''', (session_id, limit))
            else:
                cursor.execute('''
                    SELECT * FROM search_history
                    ORDER BY created_at DESC
                    LIMIT ?
                ''', (limit,))
            
            rows = cursor.fetchall()
            return [self._row_to_dict(row) for row in rows]
    
    def get_session_history(self, session_id: str) -> List[Dict]:
        """Get all queries for a specific session"""
        return self.get_search_history(session_id=session_id, limit=1000)
    
    def save_metric(self, event_type: str, event_data: Dict, 
                   duration_ms: Optional[int] = None, success: bool = True,
                   error_message: Optional[str] = None):
        """Save a metric event"""
        logger.debug(f"Saving metric: {event_type} (success: {success}, duration: {duration_ms}ms)")
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO metrics (event_type, event_data, duration_ms, success, error_message)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                event_type,
                json.dumps(event_data),
                duration_ms,
                success,
                error_message
            ))
            conn.commit()
            logger.debug(f"Metric saved: {event_type}")
    
    def get_metrics(self, event_type: Optional[str] = None,
                   start_date: Optional[datetime] = None,
                   end_date: Optional[datetime] = None) -> List[Dict]:
        """Get metrics data"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            query = 'SELECT * FROM metrics WHERE 1=1'
            params = []
            
            if event_type:
                query += ' AND event_type = ?'
                params.append(event_type)
            
            if start_date:
                query += ' AND created_at >= ?'
                params.append(start_date.isoformat())
            
            if end_date:
                query += ' AND created_at <= ?'
                params.append(end_date.isoformat())
            
            query += ' ORDER BY created_at DESC LIMIT 1000'
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            return [self._row_to_dict(row) for row in rows]
    
    def get_metrics_summary(self, days: int = 7) -> Dict:
        """Get metrics summary for the last N days"""
        logger.debug(f"Calculating metrics summary for last {days} days")
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Total queries
            cursor.execute('''
                SELECT COUNT(*) as count, 
                       AVG(response_time_ms) as avg_response_time,
                       MIN(response_time_ms) as min_response_time,
                       MAX(response_time_ms) as max_response_time
                FROM search_history
                WHERE created_at >= datetime('now', '-' || ? || ' days')
            ''', (days,))
            query_stats = cursor.fetchone()
            
            # Success rate
            cursor.execute('''
                SELECT 
                    COUNT(*) as total,
                    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful
                FROM metrics
                WHERE event_type = 'query' 
                AND created_at >= datetime('now', '-' || ? || ' days')
            ''', (days,))
            success_stats = cursor.fetchone()
            
            # Queries per day
            cursor.execute('''
                SELECT DATE(created_at) as date, COUNT(*) as count
                FROM search_history
                WHERE created_at >= datetime('now', '-' || ? || ' days')
                GROUP BY DATE(created_at)
                ORDER BY date DESC
            ''', (days,))
            daily_queries = cursor.fetchall()
            
            # Top questions
            cursor.execute('''
                SELECT question, COUNT(*) as count
                FROM search_history
                WHERE created_at >= datetime('now', '-' || ? || ' days')
                GROUP BY question
                ORDER BY count DESC
                LIMIT 10
            ''', (days,))
            top_questions = cursor.fetchall()
            
            return {
                'total_queries': query_stats['count'] if query_stats else 0,
                'avg_response_time_ms': query_stats['avg_response_time'] if query_stats else 0,
                'min_response_time_ms': query_stats['min_response_time'] if query_stats else 0,
                'max_response_time_ms': query_stats['max_response_time'] if query_stats else 0,
                'success_rate': (success_stats['successful'] / success_stats['total'] * 100) 
                               if success_stats and success_stats['total'] > 0 else 0,
                'daily_queries': [{'date': row['date'], 'count': row['count']} 
                                 for row in daily_queries],
                'top_questions': [{'question': row['question'], 'count': row['count']} 
                                for row in top_questions]
            }
    
    def _row_to_dict(self, row) -> Dict:
        """Convert SQLite row to dictionary"""
        return dict(row)

