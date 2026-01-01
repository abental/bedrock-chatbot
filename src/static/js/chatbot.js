// Chatbot JavaScript with History, Context Transparency, and Enhanced Features

let currentSessionId = null;
let currentSources = [];
let conversationHistory = [];
let currentQueryId = null; // Track current query ID for history
let previousSessionId = null; // Track previous session for cleanup

// Storage key prefix
const STORAGE_PREFIX = 'bedrock_chatbot_';
const STORAGE_KEY_CURRENT_SESSION = 'bedrock_chatbot_current_session'; // Stores the current active session ID

// Helper function to get session-specific storage keys
function getStorageKey(suffix) {
    if (!currentSessionId) {
        // If no session ID yet, use a temporary key that will be migrated when session is created
        return `${STORAGE_PREFIX}temp_${suffix}`;
    }
    return `${STORAGE_PREFIX}session_${currentSessionId}_${suffix}`;
}

// Helper function to get all storage keys for a specific session
function getSessionStorageKeys(sessionId) {
    return {
        sessionId: `${STORAGE_PREFIX}session_${sessionId}_session_id`,
        conversation: `${STORAGE_PREFIX}session_${sessionId}_conversation`,
        sources: `${STORAGE_PREFIX}session_${sessionId}_sources`,
        messages: `${STORAGE_PREFIX}session_${sessionId}_messages`
    };
}

// Clean up old session data (optional - can be called when switching sessions)
function cleanupOldSession(sessionId) {
    if (!sessionId) return;
    const keys = getSessionStorageKeys(sessionId);
    localStorage.removeItem(keys.sessionId);
    localStorage.removeItem(keys.conversation);
    localStorage.removeItem(keys.sources);
    localStorage.removeItem(keys.messages);
}

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    initializeChatbot();
    restoreChatState();
    loadHistory();
    
    // Save state before page unload
    window.addEventListener('beforeunload', saveChatState);
    
    // Save state periodically (every 5 seconds) to catch navigation
    setInterval(saveChatState, 5000);
});

function initializeChatbot() {
    const chatForm = document.getElementById('chatForm');
    const historyToggle = document.getElementById('historyToggle');
    const sourcesToggle = document.getElementById('sourcesToggle');
    const closeHistory = document.getElementById('closeHistory');
    const closeSources = document.getElementById('closeSources');

    chatForm.addEventListener('submit', handleSubmit);
    historyToggle.addEventListener('click', toggleHistory);
    sourcesToggle.addEventListener('click', toggleSources);
    closeHistory.addEventListener('click', () => toggleHistory(false));
    closeSources.addEventListener('click', () => toggleSources(false));
}

async function handleSubmit(e) {
    e.preventDefault();
    
    const questionInput = document.getElementById('questionInput');
    const question = questionInput.value.trim();
    
    if (!question) return;
    
    // Disable input
    questionInput.disabled = true;
    const submitBtn = document.getElementById('submitBtn');
    submitBtn.disabled = true;
    submitBtn.querySelector('.btn-text').style.display = 'none';
    submitBtn.querySelector('.btn-spinner').style.display = 'inline';
    
    // Add user message
    addMessage('user', question);
    questionInput.value = '';
    
    try {
        const response = await fetch('/api/ask', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                question: question,
                session_id: currentSessionId,
                use_advanced_prompts: true
            })
        });
        
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'Failed to get response');
        }
        
        // Store session ID
        const newSessionId = data.session_id;
        
        // If session ID changed, save current state to old session before switching
        if (currentSessionId && currentSessionId !== newSessionId) {
            previousSessionId = currentSessionId;
            // Save current state to old session
            saveChatState();
            // Clear current variables to start fresh for new session
            conversationHistory = [];
            currentSources = [];
        }
        
        currentSessionId = newSessionId;
        
        // Store current session ID for quick lookup
        if (currentSessionId) {
            localStorage.setItem(STORAGE_KEY_CURRENT_SESSION, currentSessionId);
        }
        
        // Store sources for context transparency
        currentSources = data.sources || [];
        
        // Store query ID for sources pagination
        currentQueryId = data.query_id;
        
        // Add assistant message with answer
        addMessage('assistant', data.answer, {
            sources: currentSources,
            responseTime: data.response_time_ms,
            queryType: data.query_type,
            queryId: data.query_id
        });
        
        // Update conversation history
        conversationHistory.push({
            question: question,
            answer: data.answer
        });
        
        // Save state after each message (now session-specific)
        saveChatState();
        
        // Reload history
        loadHistory();
        
    } catch (error) {
        console.error('Error:', error);
        addMessage('error', `Error: ${error.message}`);
    } finally {
        // Re-enable input
        questionInput.disabled = false;
        submitBtn.disabled = false;
        submitBtn.querySelector('.btn-text').style.display = 'inline';
        submitBtn.querySelector('.btn-spinner').style.display = 'none';
        questionInput.focus();
    }
}

function addMessage(role, content, metadata = {}) {
    const chatMessages = document.getElementById('chatMessages');
    
    // Remove welcome message if it exists and we're adding a real message
    const welcomeMsg = chatMessages.querySelector('.welcome-message');
    if (welcomeMsg && (role === 'user' || role === 'assistant')) {
        welcomeMsg.remove();
    }
    
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${role}-message`;
    
    if (role === 'user') {
        messageDiv.innerHTML = `
            <div class="message-content">
                <strong>You:</strong> ${escapeHtml(content)}
            </div>
        `;
    } else if (role === 'assistant') {
        const sourcesCount = metadata.sources ? metadata.sources.length : 0;
        const responseTime = metadata.responseTime ? `${metadata.responseTime}ms` : '';
        const queryType = metadata.queryType ? `Type: ${metadata.queryType}` : '';
        
        // Check if content is already HTML (from restore) or plain text
        const isHtml = content.includes('<') && (content.includes('<strong>') || content.includes('<em>') || content.includes('<code>') || content.includes('<br>'));
        const formattedContent = isHtml ? content : formatMarkdown(content);
        
        messageDiv.innerHTML = `
            <div class="message-content">
                <strong>Assistant:</strong>
                <div class="answer-content">${formattedContent}</div>
                ${sourcesCount > 0 ? `
                    <div class="message-metadata">
                        <span class="sources-badge">📚 ${sourcesCount} source${sourcesCount > 1 ? 's' : ''}</span>
                        ${responseTime ? `<span class="response-time-badge">⏱️ ${responseTime}</span>` : ''}
                        ${queryType ? `<span class="query-type-badge">${queryType}</span>` : ''}
                    </div>
                ` : ''}
            </div>
        `;
        
        // Store sources in data attribute for state persistence
        if (metadata.sources && metadata.sources.length > 0) {
            messageDiv.dataset.sources = JSON.stringify(metadata.sources);
        }
        
        // Update sources panel if open
        if (document.getElementById('sourcesPanel').classList.contains('visible')) {
            loadDocuments();
        }
    } else if (role === 'error') {
        messageDiv.innerHTML = `
            <div class="message-content error">
                <strong>Error:</strong> ${escapeHtml(content)}
            </div>
        `;
    }
    
    chatMessages.appendChild(messageDiv);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    
    // Return the message div for potential further manipulation
    return messageDiv;
}

function formatMarkdown(text) {
    // Simple markdown formatting
    return escapeHtml(text)
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/`(.*?)`/g, '<code>$1</code>')
        .replace(/\n/g, '<br>');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function toggleHistory(show = null) {
    const sidebar = document.getElementById('historySidebar');
    const isHidden = sidebar.classList.contains('hidden');
    const shouldShow = show !== null ? show : isHidden;
    
    if (shouldShow) {
        sidebar.classList.remove('hidden');
        sidebar.classList.add('visible');
        loadHistory();
    } else {
        sidebar.classList.remove('visible');
        sidebar.classList.add('hidden');
    }
}

function toggleSources(show = null) {
    const panel = document.getElementById('sourcesPanel');
    const isHidden = panel.classList.contains('hidden');
    const shouldShow = show !== null ? show : isHidden;
    
    if (shouldShow) {
        panel.classList.remove('hidden');
        panel.classList.add('visible');
        // Load documents from knowledge base
        loadDocuments();
    } else {
        panel.classList.remove('visible');
        panel.classList.add('hidden');
    }
}

async function loadHistory() {
    try {
        // Fetch all questions (not filtered by session_id) to display in Search History panel
        const response = await fetch(`/api/history?limit=100`);
        const data = await response.json();
        
        const historyList = document.getElementById('historyList');
        
        if (!data.history || data.history.length === 0) {
            historyList.innerHTML = '<p class="empty-state">No search history yet</p>';
            return;
        }
        
        historyList.innerHTML = data.history.map(item => `
            <div class="history-item" onclick="loadHistoryItem(${item.id})">
                <div class="history-question">${escapeHtml(item.question)}</div>
                <div class="history-meta">
                    <span class="history-time">${formatDate(item.created_at)}</span>
                    ${item.sources ? `<span class="history-sources">${JSON.parse(item.sources).length} sources</span>` : ''}
                </div>
            </div>
        `).join('');
    } catch (error) {
        console.error('Error loading history:', error);
        const historyList = document.getElementById('historyList');
        historyList.innerHTML = '<p class="empty-state">Error loading history</p>';
    }
}

async function loadHistoryItem(queryId) {
    try {
        currentQueryId = queryId;
        // Just toggle sources panel to show documents (no longer query-specific)
        toggleSources(true);
        
        // Scroll to message if it exists in chat
        const chatMessages = document.getElementById('chatMessages');
        chatMessages.scrollTop = chatMessages.scrollHeight;
    } catch (error) {
        console.error('Error loading history item:', error);
    }
}

async function loadDocuments() {
    const sourcesContent = document.getElementById('sourcesContent');
    
    // Show loading state
    sourcesContent.innerHTML = '<p class="empty-state">Loading documents...</p>';
    
    try {
        const response = await fetch(`/api/sources`);
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'Failed to load documents');
        }
        
        console.log('Documents loaded:', data);
        displayDocuments(data);
    } catch (error) {
        console.error('Error loading documents:', error);
        sourcesContent.innerHTML = `<p class="empty-state">Error loading documents: ${error.message}</p>`;
    }
}

function displayDocuments(data) {
    const sourcesContent = document.getElementById('sourcesContent');
    
    if (!data.documents || data.documents.length === 0) {
        sourcesContent.innerHTML = '<p class="empty-state">No documents in knowledge base</p>';
        return;
    }
    
    // Format file sizes
    function formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    let html = `<div class="documents-list">`;
    html += `<div class="documents-header">Total: ${data.count} document${data.count !== 1 ? 's' : ''}</div>`;
    
    data.documents.forEach((doc) => {
        const docName = doc.name || 'Unknown Document';
        const docSize = formatFileSize(doc.size || 0);
        
        html += `
            <div class="document-item">
                <div class="document-header">
                    <h4 class="document-name">📄 ${escapeHtml(docName)}</h4>
                    <span class="document-size">${docSize}</span>
                </div>
            </div>
        `;
    });
    
    html += `</div>`;
    
    sourcesContent.innerHTML = html;
}

// Legacy function for backward compatibility
function displaySourcesLegacy(sources) {
    const sourcesContent = document.getElementById('sourcesContent');
    
    if (!sources || sources.length === 0) {
        sourcesContent.innerHTML = '<p class="empty-state">No sources available</p>';
        return;
    }
    
    sourcesContent.innerHTML = sources.map((source, index) => {
        const content = source.content || '';
        const s3Uri = source.s3_uri || source.location?.s3Location?.uri || '';
        const score = source.score || 0;
        const s3Key = source.s3_key || s3Uri.split('/').pop() || 'Unknown';
        
        return `
            <div class="source-item">
                <div class="source-header">
                    <span class="source-number">Source ${index + 1}</span>
                    ${score > 0 ? `<span class="source-score">Score: ${score.toFixed(3)}</span>` : ''}
                </div>
                ${s3Key !== 'Unknown' ? `<div class="source-location">📄 ${s3Key}</div>` : ''}
                <div class="source-content">${escapeHtml(content.substring(0, 500))}${content.length > 500 ? '...' : ''}</div>
            </div>
        `;
    }).join('');
}

// Make functions available globally
window.loadDocuments = loadDocuments;

function formatDate(dateString) {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleString();
}

// Save chat state to localStorage (session-specific)
function saveChatState() {
    try {
        if (!currentSessionId) {
            // If no session ID yet, don't save (will save after first query)
            return;
        }
        
        // Save current session ID for quick lookup
        localStorage.setItem(STORAGE_KEY_CURRENT_SESSION, currentSessionId);
        
        // Save session ID in session-specific storage
        localStorage.setItem(getStorageKey('session_id'), currentSessionId);
        
        // Save conversation history
        if (conversationHistory.length > 0) {
            localStorage.setItem(getStorageKey('conversation'), JSON.stringify(conversationHistory));
        }
        
        // Save current sources
        if (currentSources.length > 0) {
            localStorage.setItem(getStorageKey('sources'), JSON.stringify(currentSources));
        }
        
        // Save chat messages from DOM
        const chatMessages = document.getElementById('chatMessages');
        if (chatMessages) {
            const messages = Array.from(chatMessages.children).map(msgEl => {
                // Skip welcome message
                if (msgEl.classList.contains('welcome-message')) {
                    return null;
                }
                
                const role = msgEl.classList.contains('user-message') ? 'user' : 
                            msgEl.classList.contains('assistant-message') ? 'assistant' : 'error';
                
                const messageContent = msgEl.querySelector('.message-content');
                if (!messageContent) return null;
                
                // Extract content based on role
                let content = '';
                let metadata = {};
                
                if (role === 'user') {
                    const strongEl = messageContent.querySelector('strong');
                    if (strongEl && strongEl.nextSibling) {
                        content = strongEl.nextSibling.textContent.trim();
                    }
                } else if (role === 'assistant') {
                    const answerContent = messageContent.querySelector('.answer-content');
                    if (answerContent) {
                        // Get HTML content, preserving basic formatting
                        content = answerContent.innerHTML;
                    }
                    
                    // Extract sources from data attribute if available
                    const savedSources = msgEl.dataset.sources;
                    if (savedSources) {
                        try {
                            metadata.sources = JSON.parse(savedSources);
                            metadata.sourcesCount = metadata.sources.length;
                        } catch (e) {
                            console.warn('Failed to parse saved sources:', e);
                        }
                    }
                    
                    // Extract metadata from UI
                    const metadataEl = messageContent.querySelector('.message-metadata');
                    if (metadataEl) {
                        const sourcesBadge = metadataEl.querySelector('.sources-badge');
                        const responseTimeBadge = metadataEl.querySelector('.response-time-badge');
                        const queryTypeBadge = metadataEl.querySelector('.query-type-badge');
                        
                        if (sourcesBadge && !metadata.sourcesCount) {
                            const sourcesMatch = sourcesBadge.textContent.match(/(\d+)/);
                            if (sourcesMatch) {
                                metadata.sourcesCount = parseInt(sourcesMatch[1]);
                            }
                        }
                        if (responseTimeBadge) {
                            const timeMatch = responseTimeBadge.textContent.match(/(\d+)ms/);
                            if (timeMatch) {
                                metadata.responseTime = parseInt(timeMatch[1]);
                            }
                        }
                        if (queryTypeBadge) {
                            metadata.queryType = queryTypeBadge.textContent.replace('Type: ', '');
                        }
                    }
                } else if (role === 'error') {
                    const strongEl = messageContent.querySelector('strong');
                    if (strongEl && strongEl.nextSibling) {
                        content = strongEl.nextSibling.textContent.trim();
                    }
                }
                
                return { role, content, metadata };
            }).filter(msg => msg !== null);
            
            if (messages.length > 0) {
                localStorage.setItem(getStorageKey('messages'), JSON.stringify(messages));
            }
        }
    } catch (error) {
        console.error('Error saving chat state:', error);
    }
}

// Restore chat state from localStorage (session-specific)
function restoreChatState() {
    try {
        // First, try to get the current active session ID
        let sessionIdToRestore = localStorage.getItem(STORAGE_KEY_CURRENT_SESSION);
        
        // If no current session, check for legacy storage (migration support)
        if (!sessionIdToRestore) {
            const legacySessionId = localStorage.getItem('bedrock_chatbot_session_id');
            if (legacySessionId) {
                sessionIdToRestore = legacySessionId;
                // Migrate to new format
                currentSessionId = legacySessionId;
                localStorage.setItem(STORAGE_KEY_CURRENT_SESSION, legacySessionId);
            }
        }
        
        // If we have a session ID, restore that session's data
        if (sessionIdToRestore) {
            currentSessionId = sessionIdToRestore;
            
            // Restore conversation history
            const savedConversation = localStorage.getItem(getStorageKey('conversation'));
            if (savedConversation) {
                conversationHistory = JSON.parse(savedConversation);
            } else {
                // Try legacy key for migration
                const legacyConversation = localStorage.getItem('bedrock_chatbot_conversation');
                if (legacyConversation) {
                    conversationHistory = JSON.parse(legacyConversation);
                    // Save to new location
                    if (conversationHistory.length > 0) {
                        localStorage.setItem(getStorageKey('conversation'), JSON.stringify(conversationHistory));
                    }
                }
            }
            
            // Restore sources
            const savedSources = localStorage.getItem(getStorageKey('sources'));
            if (savedSources) {
                currentSources = JSON.parse(savedSources);
            } else {
                // Try legacy key for migration
                const legacySources = localStorage.getItem('bedrock_chatbot_sources');
                if (legacySources) {
                    currentSources = JSON.parse(legacySources);
                    // Save to new location
                    if (currentSources.length > 0) {
                        localStorage.setItem(getStorageKey('sources'), JSON.stringify(currentSources));
                    }
                }
            }
            
            // Restore chat messages
            const savedMessages = localStorage.getItem(getStorageKey('messages'));
            if (savedMessages) {
                const messages = JSON.parse(savedMessages);
                const chatMessages = document.getElementById('chatMessages');
                
                // Clear welcome message if we have saved messages
                if (messages.length > 0) {
                    const welcomeMsg = chatMessages.querySelector('.welcome-message');
                    if (welcomeMsg) {
                        welcomeMsg.remove();
                    }
                    
                    // Restore each message
                    messages.forEach(msg => {
                        if (msg.role === 'assistant') {
                            // Use sources from metadata if available, otherwise use currentSources
                            const sources = msg.metadata?.sources || (msg.metadata?.sourcesCount ? currentSources : []);
                            addMessage(msg.role, msg.content, {
                                sources: sources,
                                responseTime: msg.metadata?.responseTime,
                                queryType: msg.metadata?.queryType
                            });
                        } else {
                            addMessage(msg.role, msg.content);
                        }
                    });
                }
            } else {
                // Try legacy key for migration
                const legacyMessages = localStorage.getItem('bedrock_chatbot_messages');
                if (legacyMessages) {
                    const messages = JSON.parse(legacyMessages);
                    const chatMessages = document.getElementById('chatMessages');
                    
                    if (messages.length > 0) {
                        const welcomeMsg = chatMessages.querySelector('.welcome-message');
                        if (welcomeMsg) {
                            welcomeMsg.remove();
                        }
                        
                        messages.forEach(msg => {
                            if (msg.role === 'assistant') {
                                const sources = msg.metadata?.sources || (msg.metadata?.sourcesCount ? currentSources : []);
                                addMessage(msg.role, msg.content, {
                                    sources: sources,
                                    responseTime: msg.metadata?.responseTime,
                                    queryType: msg.metadata?.queryType
                                });
                            } else {
                                addMessage(msg.role, msg.content);
                            }
                        });
                        
                        // Save to new location
                        localStorage.setItem(getStorageKey('messages'), legacyMessages);
                    }
                }
            }
        }
    } catch (error) {
        console.error('Error restoring chat state:', error);
        // Clear corrupted state
        clearChatState();
    }
}

// Clear chat state (useful for starting fresh)
function clearChatState() {
    // Clear current session data
    if (currentSessionId) {
        const keys = getSessionStorageKeys(currentSessionId);
        localStorage.removeItem(keys.sessionId);
        localStorage.removeItem(keys.conversation);
        localStorage.removeItem(keys.sources);
        localStorage.removeItem(keys.messages);
    }
    
    // Clear legacy keys (for migration cleanup)
    localStorage.removeItem('bedrock_chatbot_session_id');
    localStorage.removeItem('bedrock_chatbot_conversation');
    localStorage.removeItem('bedrock_chatbot_sources');
    localStorage.removeItem('bedrock_chatbot_messages');
    
    // Clear current session reference
    localStorage.removeItem(STORAGE_KEY_CURRENT_SESSION);
    
    currentSessionId = null;
    currentSources = [];
    conversationHistory = [];
    
    // Clear the chat UI
    const chatMessages = document.getElementById('chatMessages');
    if (chatMessages) {
        chatMessages.innerHTML = `
            <div class="welcome-message">
                <p>👋 Welcome! Ask me anything about the knowledge base.</p>
                <p class="subtitle">Your questions and answers will be saved in history</p>
            </div>
        `;
    }
}

// Make functions available globally
window.loadHistoryItem = loadHistoryItem;
window.clearChatState = clearChatState; // Allow manual clearing if needed
