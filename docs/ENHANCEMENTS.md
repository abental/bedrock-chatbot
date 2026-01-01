# Chatbot Enhancements Documentation

This document describes the new features added to the Bedrock Knowledge Base Chatbot application.

## Overview

The following enhancements have been implemented:

1. **Search History** - Store and retrieve previous queries
2. **Context Transparency** - Display retrieved sources and context
3. **Advanced Prompt Logic** - Enhanced prompt engineering with system prompts and templates
4. **Metrics Dashboard** - Track and visualize usage metrics
5. **Admin Authentication** - Password-protected admin interface with session management
6. **Modular Architecture** - Package-based code organization with Flask Blueprints

---

## 1. Search History

### Features
- Automatic storage of all queries and answers
- Session-based history tracking
- History sidebar with clickable items
- Query details retrieval

### Implementation

**Backend:**
- `database.py` - SQLite database for storing search history
- `app.py` - New endpoints:
  - `GET /api/history` - Get search history
  - `GET /api/history/<query_id>` - Get specific query details

**Frontend:**
- History sidebar with toggle button
- Clickable history items
- Session-based filtering

### Usage

Users can:
- Click the "📜 History" button to view past queries
- Click on any history item to see sources
- View queries from current session or all sessions

---

## 2. Context Transparency

### Features
- Display retrieved sources for each answer
- Show source metadata (S3 URI, score, content)
- Expandable sources panel
- Source highlighting in answers

### Implementation

**Backend:**
- Enhanced `bedrock_utils.py` to return detailed source information
- Source formatting with location and score data

**Frontend:**
- Sources panel that can be toggled
- Source cards showing:
  - Source number and score
  - S3 location
  - Content preview
- Sources badge in chat messages

### Usage

Users can:
- Click the "📚 Sources" button to view retrieved sources
- See which documents were used to generate answers
- View source scores and locations

---

## 3. Advanced Prompt Logic

### Features
- System prompts for better answer quality
- Query type detection (general, technical, summary, comparison)
- Few-shot examples support
- Conversation history integration
- Prompt templates for different query types

### Implementation

**Backend:**
- `prompt_engine.py` - New module for prompt engineering
- Features:
  - System prompt configuration
  - Query type detection
  - Few-shot examples
  - Prompt templates
  - Conversation context enhancement

**Configuration:**
- `SYSTEM_PROMPT` - Custom system instructions
- `FEW_SHOT_EXAMPLES` - JSON array of examples

### Query Types

1. **General** - Default query type
2. **Technical** - For how-to and implementation questions
3. **Summary** - For summarization requests
4. **Comparison** - For comparison questions

### Usage

The system automatically:
- Detects query type based on keywords
- Enhances queries with conversation history
- Applies appropriate prompt templates
- Uses system prompts for better responses

---

## 4. Metrics Dashboard

### Features
- Query statistics (total, average response time, etc.)
- Success rate tracking
- Daily query volume
- Top questions analysis
- Time-based filtering (1, 7, 30, 90 days)

### Implementation

**Backend:**
- `database.py` - Metrics storage and aggregation
- `app.py` - New endpoints:
  - `GET /api/metrics` - Get metrics data
  - `GET /api/metrics/summary` - Get metrics summary

**Frontend:**
- Metrics dashboard in admin panel
- Visual cards for key metrics
- Daily query volume chart
- Top questions list

### Metrics Tracked

1. **Query Metrics:**
   - Total queries
   - Average response time
   - Min/Max response times
   - Success rate

2. **Usage Metrics:**
   - Daily query volume
   - Top questions
   - Session statistics

3. **Performance Metrics:**
   - Response times
   - Error rates
   - Source retrieval counts

### Usage

Admins can:
- View metrics in the admin dashboard
- Filter by time period
- See top questions
- Monitor performance trends

---

## Database Schema

### Tables

1. **search_history**
   - Stores all queries and answers
   - Includes sources, metadata, timestamps

2. **metrics**
   - Tracks events and performance
   - Stores event data as JSON

3. **sessions**
   - Tracks user sessions
   - Maintains query counts per session

---

## API Endpoints

### New Endpoints

#### Search History
- `GET /api/history?session_id=<id>&limit=<n>` - Get history
- `GET /api/history/<query_id>` - Get query details

#### Metrics
- `GET /api/metrics?event_type=<type>&days=<n>` - Get metrics
- `GET /api/metrics/summary?days=<n>` - Get summary

### Enhanced Endpoints

#### `/api/ask`
Now returns:
- `query_id` - ID for history lookup
- `response_time_ms` - Response time
- `query_type` - Detected query type
- `enhanced_question` - Enhanced query (if applicable)
- Enhanced `sources` with more metadata

---

## Configuration

### Environment Variables

```bash
# Optional: Custom system prompt
SYSTEM_PROMPT="Your custom system prompt here"

# Optional: Few-shot examples (JSON)
FEW_SHOT_EXAMPLES='[{"question": "...", "context": "...", "answer": "..."}]'
```

### Database Location

Default: `data/chatbot.db`

The database is automatically created on first run.

---

## File Structure

```
src/
├── app.py                    # Main application entry point
├── api/                      # REST API routes (Flask Blueprints)
│   ├── chatbot.py           # Chatbot endpoints
│   ├── history.py           # Search history endpoints
│   ├── admin.py             # Admin endpoints
│   ├── metrics.py           # Analytics endpoints
│   └── health.py            # Health check endpoints
├── db/                       # Database layer
│   └── database.py          # SQLite operations
├── kb/                       # Knowledge Base integration
│   └── bedrock.py           # AWS Bedrock client
├── config/                   # Configuration management
│   ├── manager.py           # Config manager
│   └── logging_config.py    # Logging configuration
├── prompt/                   # Prompt engineering
│   └── engine.py            # Advanced prompt logic
├── templates/                # HTML templates
│   ├── chatbot.html         # Enhanced UI
│   ├── admin_login.html     # Admin login page
│   └── admin_dashboard.html # Metrics dashboard
├── static/                   # Static files
│   ├── js/
│   │   ├── chatbot.js       # Enhanced with history/sources
│   │   ├── admin.js         # Admin authentication
│   │   └── admin_dashboard.js # Metrics dashboard
│   └── css/
│       ├── chatbot.css      # Enhanced styles
│       └── admin.css        # Metrics styles
└── data/                     # Database directory (auto-created)
    └── chatbot.db           # SQLite database
```

---

## Usage Examples

### Search History

```javascript
// Get history for current session
fetch('/api/history?session_id=xxx&limit=50')
  .then(res => res.json())
  .then(data => console.log(data.history));
```

### Metrics

```javascript
// Get metrics summary for last 7 days
fetch('/api/metrics/summary?days=7')
  .then(res => res.json())
  .then(data => console.log(data));
```

### Advanced Prompts

The system automatically uses advanced prompts. To customize:

1. Set `SYSTEM_PROMPT` environment variable
2. Configure `FEW_SHOT_EXAMPLES` for examples
3. Query types are auto-detected

---

## Future Enhancements

Potential additions:
- Export history to CSV/JSON
- Advanced analytics and charts
- User feedback collection
- A/B testing for prompts
- Real-time metrics streaming
- Custom prompt templates per user

---

## 5. Admin Authentication & Session Management

### Features
- Password-protected admin interface
- Secure session management with Flask sessions
- Session persistence (1 hour)
- HttpOnly cookies for security
- Works behind NGINX reverse proxy

### Implementation

**Backend:**
- `api/admin.py` - Admin authentication and authorization
- `api/utils.py` - `@admin_required` decorator for protected routes
- Session-based authentication with permanent sessions

**Frontend:**
- `admin_login.html` - Clean login interface
- `admin_dashboard.html` - Protected admin dashboard
- JavaScript-based login with AJAX

### Security Features
- Constant-time password comparison
- Session cookie with HttpOnly and SameSite=Lax
- ProxyFix middleware for correct client IP detection behind NGINX
- Admin password stored in external file

---

## 6. Modular Architecture

### Features
- Package-based code organization
- Flask Blueprints for API routes
- Separation of concerns
- Centralized logging configuration (INI file)

### Implementation

**API Routes (Blueprints):**
- `api/chatbot.py` - `/api/ask`
- `api/history.py` - `/api/history`, `/api/sources`
- `api/admin.py` - `/api/admin/*`
- `api/metrics.py` - `/api/metrics`
- `api/health.py` - `/api/health`

**Configuration:**
- `config/manager.py` - Centralized configuration
- `logging.ini` - INI-based logging configuration

---

## AI Model

The application uses **OpenAI GPT OSS 120B** (openai.gpt-oss-120b-1:0) as the primary foundation model, with **Claude Sonnet 3.5** (anthropic.claude-3-5-sonnet-20241022-v2:0) as an alternative option for answer generation.

---

## Notes

- Database is SQLite (file-based) for simplicity
- For production, consider PostgreSQL or DynamoDB
- Metrics are stored indefinitely (consider retention policies)
- History can grow large - consider archiving old data
- Admin sessions expire after 1 hour of inactivity
- Application runs on port 8080 with Gunicorn behind NGINX





