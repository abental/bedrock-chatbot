# Why Use Gunicorn Instead of `python app.py`?

## Quick Answer

**Gunicorn** is a production-grade WSGI HTTP server, while `python app.py` uses Flask's built-in development server, which is **not suitable for production**.

## Key Differences

### Flask Development Server (`python app.py`)

❌ **Not for Production:**
- Single-threaded - can only handle one request at a time
- No process management - crashes take down the entire app
- Poor performance under load
- Security warnings in Flask itself
- No worker processes - can't utilize multiple CPU cores
- Limited error recovery

✅ **Good for:**
- Local development
- Quick testing
- Learning Flask

### Gunicorn (`gunicorn -w 4 -b 0.0.0.0:8080 app:app`)

✅ **Production-Ready:**
- **Multiple workers** (`-w 4` = 4 worker processes)
  - Can handle multiple requests concurrently
  - Utilizes multiple CPU cores
  - If one worker crashes, others continue serving requests

- **Better performance**
  - Optimized for production workloads
  - Handles thousands of concurrent connections
  - Better memory management

- **Process management**
  - Automatic worker restarts on crashes
  - Graceful shutdown handling
  - Better resource management
  - Managed by systemd service

- **Security**
  - Production-grade security features
  - No security warnings
  - Proper request handling
  - Works behind NGINX reverse proxy

- **Timeout handling** (`--timeout 120`)
  - Prevents hung requests from blocking workers (important for Bedrock API calls)
  - Automatic cleanup of stuck processes

## Our Configuration

### EC2 Production Deployment (Systemd)

```ini
# /etc/systemd/system/bedrock-chatbot.service
ExecStart=/app/venv/bin/gunicorn -w 4 -b 0.0.0.0:8080 --timeout 120 --chdir /app app:app
```

**Parameters:**
- `-w 4`: 4 worker processes (adjust based on CPU cores)
- `-b 0.0.0.0:8080`: Bind to all interfaces on port 8080
- `--timeout 120`: Kill workers that don't respond within 120 seconds (important for Bedrock API latency)
- `--chdir /app`: Change to application directory
- `app:app`: Module `app`, variable `app` (Flask application instance)

### Docker Deployment

```dockerfile
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "--timeout", "120", "app:app"]
```

## Development vs Production

### For Local Development

**Option 1: Flask Development Server**

```bash
cd src
python app.py
```

This gives you:
- Auto-reload on code changes
- Better error messages
- Easier debugging
- Runs on port 8080 (configurable via `APP_PORT`)

**Option 2: Docker with Flask Dev Server**

We provide a `docker-compose.override.yaml.example` that uses Flask's dev server:

```yaml
command: ["python", "app.py"]
```

**To use it:**
```bash
cp docker-compose.override.yaml.example docker-compose.override.yaml
docker-compose up
```

### For Production

**EC2 Deployment (Recommended):**

1. Uses **Gunicorn** with 4 workers
2. Managed by **systemd** service
3. Behind **NGINX** reverse proxy (port 80/443 → 8080)
4. Automatic restart on failure
5. Log management via systemd journal

```bash
# View logs
sudo journalctl -u bedrock-chatbot -f

# Restart service
sudo systemctl restart bedrock-chatbot
```

**Docker Deployment:**

The Dockerfile uses Gunicorn by default:
- Better performance
- Multiple concurrent requests
- Production-grade stability

## When to Use Each

| Scenario | Use |
|----------|-----|
| Local development | `python app.py` (via override file) |
| Production deployment | `gunicorn` (default in Dockerfile) |
| Testing | Either (gunicorn recommended for load testing) |
| CI/CD | `gunicorn` (mimics production) |

## Performance Comparison

**Flask Dev Server:**
- ~50-100 requests/second
- Single request at a time
- High latency under load

**Gunicorn (4 workers):**
- ~500-1000+ requests/second
- 4 concurrent requests
- Much lower latency under load

## Best Practices

1. **Always use Gunicorn in production** ✅
2. **Use Flask dev server only for local development** ✅
3. **Set worker count** based on CPU cores: `(2 × CPU cores) + 1`
4. **Set appropriate timeout** for your use case (120s for Bedrock API calls)
5. **Monitor worker health** and restart if needed

## Deployment Architecture

### Production Stack on EC2

```
Internet → NGINX (Port 80/443) → Gunicorn (Port 8080) → Flask App
                 ↓
          Systemd Service Management
                 ↓
          Systemd Journal Logging
```

**Benefits:**
- **NGINX**: SSL termination, static file serving, reverse proxy
- **Gunicorn**: Multiple workers, process management
- **Systemd**: Service management, automatic restart, logging
- **Flask**: Application logic

### Log Locations

- **Application logs**: `sudo journalctl -u bedrock-chatbot -f`
- **NGINX access logs**: `/var/log/nginx/bedrock-chatbot-access.log`
- **NGINX error logs**: `/var/log/nginx/bedrock-chatbot-error.log`

## Summary

- **EC2 Production**: Uses `systemd` + `gunicorn` + `NGINX` - production-ready, handles multiple requests
- **Docker Production**: Uses `gunicorn` - containerized, handles multiple requests
- **Local Development**: Uses `python app.py` - easier debugging, auto-reload
- **Best Practice**: Use the right tool for the right environment

## Port Configuration

- **Flask Development**: Port 8080 (default, configurable via `APP_PORT`)
- **Gunicorn**: Port 8080 (bound to 0.0.0.0)
- **NGINX**: Port 80 (HTTP) and 443 (HTTPS) → proxies to 8080
- **Access**: `http://your-domain/` or `http://ec2-ip/`





