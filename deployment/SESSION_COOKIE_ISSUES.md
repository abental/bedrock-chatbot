# Why Session Cookies Work Locally But Not on EC2

## Key Differences Between Local and EC2 Environments

### 1. **Localhost vs Real Domain**
- **Local**: Accessing via `localhost` or `127.0.0.1`
  - Browsers treat localhost specially - more lenient with cookies
  - SameSite cookie restrictions are relaxed for localhost
  - No domain restrictions on cookies
  
- **EC2**: Accessing via real domain (e.g., `ec2-13-223-175-42.compute-1.amazonaws.com`)
  - Browsers enforce stricter cookie policies
  - SameSite restrictions are fully enforced
  - Domain restrictions apply

### 2. **Direct Flask vs NGINX Proxy**
- **Local**: Flask dev server runs directly on `localhost:8080`
  - Cookies are set directly by Flask
  - No proxy interference
  
- **EC2**: NGINX proxies requests to Flask
  - NGINX sits between browser and Flask
  - Cookies must pass through NGINX proxy
  - NGINX needs special configuration to preserve cookies

### 3. **Cookie Path and Domain Issues**
When Flask sets a cookie behind NGINX:
- The cookie might have the wrong path if NGINX doesn't preserve it
- The cookie domain might be incorrect
- NGINX's `proxy_cookie_path` directive is needed to fix cookie paths

### 4. **SameSite Cookie Behavior**
- **Localhost**: Browsers allow SameSite=Lax cookies even for cross-site requests
- **Real Domain**: Browsers strictly enforce SameSite policies
- This is why `SESSION_COOKIE_SAMESITE = 'Lax'` works locally but might need adjustment on EC2

## Solutions Applied

### 1. NGINX Configuration (`nginx-bedrock-chatbot.conf`)
Added `proxy_cookie_path / /;` to ensure cookies from Flask are preserved with correct path.

### 2. Flask Session Configuration
- `SESSION_COOKIE_SECURE = False` (required for HTTP, not HTTPS)
- `SESSION_COOKIE_SAMESITE = 'Lax'` (allows cookies with same-site requests)
- No explicit domain setting (lets browser use default)

### 3. Server-Side Redirects
Changed from JSON response + client redirect to server-side redirect to ensure session cookie is included in redirect response.

## Testing Locally vs Production

To test locally with similar conditions to EC2:

1. **Use a real domain**: Add to `/etc/hosts`:
   ```
   127.0.0.1 bedrock-chatbot.local
   ```
   Then access via `http://bedrock-chatbot.local`

2. **Run behind NGINX locally**: Set up NGINX locally to proxy to Flask

3. **Check browser DevTools**: 
   - Application → Cookies to see if cookies are being set
   - Network tab to see Set-Cookie headers

## Common Issues and Fixes

### Issue: Cookies not being set
**Fix**: Ensure `SESSION_COOKIE_SECURE = False` for HTTP

### Issue: Cookies set but not sent with requests
**Fix**: Add `proxy_cookie_path / /;` to NGINX config

### Issue: Session lost after redirect
**Fix**: Use server-side redirects instead of client-side redirects

### Issue: Different behavior between browsers
**Fix**: Check SameSite cookie settings - some browsers are stricter

## Debugging Session Issues

1. **Check NGINX logs**: Look for cookie-related issues
2. **Check Flask logs**: Verify session is being set
3. **Browser DevTools**: 
   - Check if cookies are present
   - Check if cookies are being sent with requests
   - Check Set-Cookie headers in responses

4. **Test with curl**:
   ```bash
   # Login
   curl -v -c cookies.txt -X POST http://your-domain/admin/login \
     -H "Content-Type: application/json" \
     -d '{"password":"your-password"}'
   
   # Check dashboard (should use cookie from cookies.txt)
   curl -v -b cookies.txt http://your-domain/admin/dashboard
   ```


