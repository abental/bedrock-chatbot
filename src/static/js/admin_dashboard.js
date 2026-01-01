// Admin Dashboard JavaScript with Metrics

document.addEventListener('DOMContentLoaded', function() {
    // Wait longer to ensure session cookie is fully available after page load
    // This is especially important after login redirect on EC2
    setTimeout(() => {
        loadKBStatus();
        loadConfiguration();
        loadMetrics();
    }, 500);  // Increased delay for EC2
    
    // Event listeners
    document.getElementById('refreshStatusBtn').addEventListener('click', loadKBStatus);
    document.getElementById('syncBtn').addEventListener('click', triggerSync);
    document.getElementById('uploadForm').addEventListener('submit', handleUpload);
    document.getElementById('refreshMetricsBtn').addEventListener('click', loadMetrics);
    document.getElementById('metricsDays').addEventListener('change', loadMetrics);
    document.getElementById('logoutBtn').addEventListener('click', handleLogout);
});

async function loadKBStatus() {
    try {
        // Log cookies before making request (for debugging)
        console.log('Loading KB status, cookies:', document.cookie);
        
        const response = await fetch('/admin/kb/status', {
            credentials: 'same-origin',  // Include session cookies
            headers: {
                'Accept': 'application/json'  // Explicitly request JSON
            }
        });
        
        console.log('KB status response:', response.status, response.statusText);
        
        // Check if response is actually JSON before parsing
        const contentType = response.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
            // If we got HTML (redirect), show error instead of redirecting
            if (response.status === 401 || response.status === 302) {
                const errorMsg = `Authentication error (${response.status}). Session may have expired.`;
                console.error('Got 401/302 on KB status:', errorMsg);
                document.getElementById('kbStatusCard').innerHTML = 
                    `<div class="error">${errorMsg}<br>Please <a href="/admin">login again</a>.</div>`;
                return;
            }
            const text = await response.text();
            if (text.includes('<!DOCTYPE') || text.includes('<html')) {
                // Got HTML instead of JSON - show error
                const errorMsg = 'Received HTML instead of JSON. Server may have redirected.';
                console.error('Got HTML instead of JSON on KB status:', errorMsg);
                document.getElementById('kbStatusCard').innerHTML = 
                    `<div class="error">${errorMsg}<br>Status: ${response.status}</div>`;
                return;
            }
            throw new Error('Invalid response format');
        }
        
        const status = await response.json();
        
        if (!response.ok) {
            // Show error instead of redirecting
            const errorMsg = status.error || `Failed to load KB status (${response.status})`;
            console.error('KB status error:', errorMsg);
            document.getElementById('kbStatusCard').innerHTML = 
                `<div class="error">${errorMsg}</div>`;
            return;
            throw new Error(status.error || 'Failed to load status');
        }
        
        const statusCard = document.getElementById('kbStatusCard');
        statusCard.innerHTML = `
            <div class="status-item">
                <span class="status-label">Status:</span>
                <span class="status-value ${status.status.toLowerCase()}">${status.status}</span>
            </div>
            <div class="status-item">
                <span class="status-label">Knowledge Base ID:</span>
                <span class="status-value">${status.knowledge_base_id}</span>
            </div>
            <div class="status-item">
                <span class="status-label">Name:</span>
                <span class="status-value">${status.name || 'N/A'}</span>
            </div>
            <div class="status-item">
                <span class="status-label">Data Sources:</span>
                <span class="status-value">${status.data_sources}</span>
            </div>
            <div class="status-item">
                <span class="status-label">S3 Documents:</span>
                <span class="status-value">${status.s3_documents}</span>
            </div>
            <div class="status-item">
                <span class="status-label">Storage Type:</span>
                <span class="status-value">${status.storage_type}</span>
            </div>
        `;
    } catch (error) {
        console.error('Error loading KB status:', error);
        document.getElementById('kbStatusCard').innerHTML = 
            `<div class="error">Error loading status: ${error.message}</div>`;
    }
}

async function triggerSync() {
    const syncBtn = document.getElementById('syncBtn');
    syncBtn.disabled = true;
    syncBtn.textContent = 'Syncing...';
    
    try {
        const response = await fetch('/admin/kb/sync', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            credentials: 'same-origin'  // Include session cookies
        });
        
        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.error || 'Sync failed');
        }
        
        alert(`Sync job started! Job ID: ${result.job_id}`);
        loadKBStatus();
    } catch (error) {
        console.error('Error triggering sync:', error);
        alert(`Error: ${error.message}`);
    } finally {
        syncBtn.disabled = false;
        syncBtn.textContent = 'Trigger Sync';
    }
}

async function handleUpload(e) {
    e.preventDefault();
    
    const fileInput = document.getElementById('fileInput');
    const uploadBtn = document.getElementById('uploadBtn');
    const uploadMessage = document.getElementById('uploadMessage');
    
    if (!fileInput.files.length) {
        uploadMessage.textContent = 'Please select a file';
        uploadMessage.className = 'message error';
        uploadMessage.style.display = 'block';
        return;
    }
    
    const formData = new FormData();
    formData.append('file', fileInput.files[0]);
    
    uploadBtn.disabled = true;
    uploadBtn.querySelector('.btn-text').style.display = 'none';
    uploadBtn.querySelector('.btn-spinner').style.display = 'inline';
    uploadMessage.style.display = 'none';
    
    try {
        const response = await fetch('/admin/upload', {
            method: 'POST',
            body: formData,
            credentials: 'same-origin'  // Include session cookies
        });
        
        const result = await response.json();
        
        if (!response.ok) {
            throw new Error(result.error || 'Upload failed');
        }
        
        uploadMessage.textContent = result.message || 'File uploaded successfully!';
        uploadMessage.className = 'message success';
        uploadMessage.style.display = 'block';
        
        fileInput.value = '';
        loadKBStatus();
    } catch (error) {
        console.error('Error uploading file:', error);
        uploadMessage.textContent = `Error: ${error.message}`;
        uploadMessage.className = 'message error';
        uploadMessage.style.display = 'block';
    } finally {
        uploadBtn.disabled = false;
        uploadBtn.querySelector('.btn-text').style.display = 'inline';
        uploadBtn.querySelector('.btn-spinner').style.display = 'none';
    }
}

async function loadConfiguration() {
    try {
        console.log('Loading configuration, cookies:', document.cookie);
        
        const response = await fetch('/admin/config', {
            credentials: 'same-origin',  // Include session cookies
            headers: {
                'Accept': 'application/json'  // Explicitly request JSON
            }
        });
        
        console.log('Config response:', response.status, response.statusText);
        
        // Check if response is actually JSON
        const contentType = response.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
            // Got HTML instead of JSON - show error
            if (response.status === 401 || response.status === 302) {
                const errorMsg = `Authentication error (${response.status}). Session may have expired.`;
                console.error('Got 401/302 on config:', errorMsg);
                const configCard = document.getElementById('configCard');
                configCard.innerHTML = 
                    `<div class="error">${errorMsg}<br>Please <a href="/admin">login again</a>.</div>`;
                return;
            }
            throw new Error('Invalid response format');
        }
        
        const config = await response.json();
        
        if (!response.ok) {
            // Show error instead of redirecting
            const errorMsg = config.error || `Failed to load configuration (${response.status})`;
            console.error('Config error:', errorMsg);
            const configCard = document.getElementById('configCard');
            configCard.innerHTML = `<div class="error">${errorMsg}</div>`;
            return;
        }
        
        const configCard = document.getElementById('configCard');
        configCard.innerHTML = `
            <div class="config-item">
                <span class="config-label">Knowledge Base ID:</span>
                <span class="config-value">${config.knowledge_base_id}</span>
            </div>
            <div class="config-item">
                <span class="config-label">Model ID:</span>
                <span class="config-value">${config.model_id}</span>
            </div>
            <div class="config-item">
                <span class="config-label">Region:</span>
                <span class="config-value">${config.region}</span>
            </div>
            <div class="config-item">
                <span class="config-label">Max Tokens:</span>
                <span class="config-value">${config.max_tokens}</span>
            </div>
            <div class="config-item">
                <span class="config-label">Temperature:</span>
                <span class="config-value">${config.temperature}</span>
            </div>
        `;
    } catch (error) {
        console.error('Error loading configuration:', error);
        document.getElementById('configCard').innerHTML = 
            `<div class="error">Error loading configuration: ${error.message}</div>`;
    }
}

async function loadMetrics() {
    const days = document.getElementById('metricsDays').value;
    const dashboard = document.getElementById('metricsDashboard');
    dashboard.innerHTML = '<div class="loading">Loading metrics...</div>';
    
    try {
        const response = await fetch(`/api/metrics/summary?days=${days}`, {
            credentials: 'same-origin',  // Include session cookies
            headers: {
                'Accept': 'application/json'  // Explicitly request JSON
            }
        });
        
        console.log('Loading metrics, cookies:', document.cookie);
        console.log('Metrics response:', response.status, response.statusText);
        
        // Check if response is actually JSON
        const contentType = response.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
            // Got HTML instead of JSON - show error
            if (response.status === 401 || response.status === 302) {
                const errorMsg = `Authentication error (${response.status}). Session may have expired.`;
                console.error('Got 401/302 on metrics:', errorMsg);
                dashboard.innerHTML = 
                    `<div class="error">${errorMsg}<br>Please <a href="/admin">login again</a>.</div>`;
                return;
            }
            throw new Error('Invalid response format');
        }
        
        const summary = await response.json();
        
        if (!response.ok) {
            // Show error instead of redirecting
            const errorMsg = summary.error || `Failed to load metrics (${response.status})`;
            console.error('Metrics error:', errorMsg);
            dashboard.innerHTML = `<div class="error">${errorMsg}</div>`;
            return;
        }
        
        dashboard.innerHTML = `
            <div class="metrics-grid">
                <div class="metric-card">
                    <div class="metric-label">Total Queries</div>
                    <div class="metric-value">${summary.total_queries || 0}</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Avg Response Time</div>
                    <div class="metric-value">${Math.round(summary.avg_response_time_ms || 0)}ms</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Min Response Time</div>
                    <div class="metric-value">${Math.round(summary.min_response_time_ms || 0)}ms</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Max Response Time</div>
                    <div class="metric-value">${Math.round(summary.max_response_time_ms || 0)}ms</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Success Rate</div>
                    <div class="metric-value">${summary.success_rate ? summary.success_rate.toFixed(1) : 0}%</div>
                </div>
            </div>
            
            ${summary.daily_queries && summary.daily_queries.length > 0 ? `
                <div class="metrics-section">
                    <h3>Daily Query Volume</h3>
                    <div class="daily-queries">
                        ${summary.daily_queries.map(day => `
                            <div class="daily-query-item">
                                <span class="daily-date">${day.date}</span>
                                <span class="daily-count">${day.count} queries</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}
            
            ${summary.top_questions && summary.top_questions.length > 0 ? `
                <div class="metrics-section">
                    <h3>Top Questions</h3>
                    <div class="top-questions">
                        ${summary.top_questions.map((q, idx) => `
                            <div class="top-question-item">
                                <span class="question-rank">#${idx + 1}</span>
                                <span class="question-text">${escapeHtml(q.question)}</span>
                                <span class="question-count">${q.count}x</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}
        `;
    } catch (error) {
        console.error('Error loading metrics:', error);
        dashboard.innerHTML = `<div class="error">Error loading metrics: ${error.message}</div>`;
    }
}

function handleLogout() {
    fetch('/admin/logout', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        credentials: 'same-origin'  // Include session cookies
    })
    .then(() => {
        window.location.href = '/admin';
    })
    .catch(error => {
        console.error('Error logging out:', error);
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
