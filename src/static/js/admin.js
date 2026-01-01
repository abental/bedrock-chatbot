/**
 * Admin authentication JavaScript
 */

document.addEventListener('DOMContentLoaded', function() {
    const loginForm = document.getElementById('loginForm');
    const logoutBtn = document.getElementById('logoutBtn');
    const errorMessage = document.getElementById('errorMessage');

    // Handle login form submission
    if (loginForm) {
        loginForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const password = document.getElementById('password').value;
            const loginBtn = document.getElementById('loginBtn');
            const btnText = loginBtn.querySelector('.btn-text');
            const btnSpinner = loginBtn.querySelector('.btn-spinner');

            // Show loading state
            loginBtn.disabled = true;
            btnText.style.display = 'none';
            btnSpinner.style.display = 'inline';
            errorMessage.style.display = 'none';

            try {
                const response = await fetch('/admin/login', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',  // Explicitly request JSON
                    },
                    credentials: 'same-origin',  // Include session cookies
                    body: JSON.stringify({ password: password })
                });

                // Check response status first
                if (!response.ok) {
                    // Error response - try to parse error message
                    try {
                        const errorData = await response.json();
                        errorMessage.textContent = errorData.error || `Login failed (status: ${response.status})`;
                    } catch (e) {
                        errorMessage.textContent = `Login failed (status: ${response.status})`;
                    }
                    errorMessage.style.display = 'block';
                    return;
                }
                
                // Success response - parse as JSON
                try {
                    const data = await response.json();
                    if (data.success && data.redirect) {
                        // Login successful!
                        // NOTE: We cannot check Set-Cookie header in JavaScript due to browser security
                        // The browser automatically handles Set-Cookie headers and hides them from JavaScript
                        // This is intentional browser security - cookies are set regardless
                        console.log('Login successful! Redirecting to:', data.redirect);
                        
                        // Redirect immediately - browser has already set the cookie
                        window.location.href = data.redirect;
                    } else {
                        errorMessage.textContent = data.error || 'Invalid password';
                        errorMessage.style.display = 'block';
                    }
                } catch (e) {
                    // Not JSON - might be HTML redirect (shouldn't happen with Accept: application/json)
                    console.warn('Unexpected response format:', e);
                    // If status is OK, assume success and redirect
                    window.location.href = '/admin/dashboard';
                }
            } catch (error) {
                console.error('Login error:', error);
                errorMessage.textContent = 'Login failed. Please try again.';
                errorMessage.style.display = 'block';
            } finally {
                loginBtn.disabled = false;
                btnText.style.display = 'inline';
                btnSpinner.style.display = 'none';
            }
        });
    }

    // Handle logout
    if (logoutBtn) {
        logoutBtn.addEventListener('click', async function() {
            try {
                const response = await fetch('/admin/logout', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    }
                });

                const data = await response.json();
                if (data.success) {
                    window.location.href = data.redirect || '/admin';
                }
            } catch (error) {
                console.error('Logout error:', error);
                window.location.href = '/admin';
            }
        });
    }
});





