-- Search history table
CREATE TABLE IF NOT EXISTS search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    sources TEXT,  -- JSON array of sources
    model_id TEXT,
    kb_id TEXT,
    response_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Metrics table
CREATE TABLE IF NOT EXISTS metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,  -- 'query', 'upload', 'sync', etc.
    event_data TEXT,  -- JSON data
    duration_ms INTEGER,
    success BOOLEAN,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User sessions table
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    query_count INTEGER DEFAULT 0
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_session_id ON search_history(session_id);
CREATE INDEX IF NOT EXISTS idx_created_at ON search_history(created_at);
CREATE INDEX IF NOT EXISTS idx_event_type ON metrics(event_type);
CREATE INDEX IF NOT EXISTS idx_metrics_created_at ON metrics(created_at);

