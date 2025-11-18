# Local AI Studio Marketplace - VPS Diagnostic & Fix Guide

## ISSUES SUMMARY

**VPS:** 31.220.109.75
**Site:** https://localai.studio
**Project Directory:** /root/localai-studio-marketplace/

### Issue 1: 500 Error on First Load
**Symptom:** White page with 500 error on initial visit, works on reload
**Root Cause:** Race condition - Host Nginx attempts to proxy to backend before containers are fully ready

### Issue 2: Background Color White → Blue Transition
**Symptom:** Site starts with white background, turns blue after user interaction
**Root Cause:** CSS not loaded on initial page load, possibly 500 error blocking stylesheets

### Issue 3: "Buy More Models" Button Doesn't Scroll
**Symptom:** Button in header doesn't scroll to marketplace section
**Root Cause:** JavaScript `scrollToMarketplace()` function targets `.models-grid` but this is inside `.messages` scrollable container

---

## ROOT CAUSE ANALYSIS

### Issue 1: Backend Startup Race Condition

**Problem:** Docker Compose healthchecks not properly configured in host Nginx proxy

Looking at `docker-compose.production.yml` lines 70-75:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s  # 40 second startup grace period
```

The healthcheck endpoint is `/api/health` but Nginx is proxying to backend before it's ready.

**Fix Strategy:**
1. Ensure healthcheck endpoint exists in backend
2. Add nginx retry logic with upstream health checks
3. Increase start_period if backend needs more warmup time

---

### Issue 2: CSS Loading Issue

**Problem:** CSS defined inline in HTML (lines 8-929) should load immediately, but 500 error prevents page render

**Fix Strategy:**
1. Fix Issue 1 (500 error) - this will resolve CSS loading
2. Add CSS cache headers in nginx config
3. Ensure proper Content-Type headers for HTML

---

### Issue 3: Scroll Function Targeting Wrong Element

**Problem:** Line 1314-1318 in `local-ai-studio-with-affiliates.html`:
```javascript
function scrollToMarketplace() {
    const marketplace = document.querySelector('.models-grid');
    if (marketplace) {
        marketplace.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}
```

The `.models-grid` is inside `.messages` container (line 1005-1223), which itself has `overflow-y: auto` (line 345).

**Fix Strategy:**
1. Scroll the `.messages` container instead of using `scrollIntoView`
2. Calculate scroll position of `.models-grid` within `.messages`
3. Use `.messages.scrollTo()` with smooth behavior

---

## FIX COMMANDS FOR VPS

### Access VPS via Terminus
Open Terminus app → Connect to "Local AI Studio" server

### Step 1: Check Current Container Status
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs backend --tail 50
docker compose -f docker-compose.production.yml logs frontend --tail 50
```

### Step 2: Fix Backend Healthcheck Endpoint

Check if backend has `/health` or `/api/health` endpoint:
```bash
# Test both endpoints
docker exec localai-backend curl -f http://localhost:8000/health
docker exec localai-backend curl -f http://localhost:8000/api/health
```

If neither works, check backend code:
```bash
docker exec localai-backend cat /app/main.py | grep -A 5 "health"
```

**Fix A:** If healthcheck endpoint missing, update `docker-compose.production.yml`:
```bash
# Change healthcheck test to match actual endpoint
# Use nano or echo to update line 71
nano /root/localai-studio-marketplace/docker-compose.production.yml

# Change from:
# test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
# To:
# test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
```

**Fix B:** Add health endpoint to backend if missing:
```bash
# This depends on your backend framework (FastAPI, Flask, etc)
# For FastAPI, add this to main.py:
docker exec localai-backend cat /app/main.py

# If using FastAPI, you need to add:
# @app.get("/health")
# async def health_check():
#     return {"status": "ok"}
```

### Step 3: Fix Nginx Configuration for Backend Retries

Check current nginx config:
```bash
cat /etc/nginx/sites-available/localai.studio
```

**Expected Issues:**
- Missing upstream block with health checks
- No retry logic for backend proxy
- No proxy timeout configuration

**Fix:** Create improved nginx configuration:
```bash
# Backup current config
cp /etc/nginx/sites-available/localai.studio /etc/nginx/sites-available/localai.studio.backup

# Create new config with upstream health checks
cat > /etc/nginx/sites-available/localai.studio << 'EOF'
upstream backend_api {
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

upstream frontend_app {
    server 127.0.0.1:3000 max_fails=3 fail_timeout=30s;
    keepalive 16;
}

server {
    listen 80;
    listen [::]:80;
    server_name localai.studio www.localai.studio;

    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name localai.studio www.localai.studio;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/localai.studio/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/localai.studio/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Root and Index
    root /var/www/html;
    index index.html;

    # Client body size
    client_max_body_size 100M;
    client_body_timeout 300s;

    # Timeouts for slow backend startup
    proxy_connect_timeout 90s;
    proxy_send_timeout 90s;
    proxy_read_timeout 90s;

    # Backend API - Retry logic with health checks
    location /api/ {
        # Return 503 with custom page if backend is down
        error_page 502 503 504 = @backend_down;

        proxy_pass http://backend_api;
        proxy_http_version 1.1;

        # Connection reuse
        proxy_set_header Connection "";

        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Retry failed requests
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
    }

    # Backend health check endpoint
    location /health {
        proxy_pass http://backend_api/health;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        access_log off;
    }

    # Frontend - All other requests
    location / {
        # Cache static assets aggressively
        location ~* \.(html|css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            proxy_pass http://frontend_app;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;

            # Cache headers for static assets
            add_header Cache-Control "public, max-age=3600" always;
            expires 1h;
        }

        # Default proxy to frontend
        proxy_pass http://frontend_app;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # No caching for HTML pages
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
        add_header Pragma "no-cache" always;
        add_header Expires "0" always;
    }

    # Backend down fallback page
    location @backend_down {
        default_type text/html;
        return 503 '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Service Starting - Local AI Studio</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #0A0E27 0%, #0F1635 50%, #1a0f35 100%);
            color: #F5F7FF;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            text-align: center;
        }
        .container {
            max-width: 600px;
            padding: 3rem;
            background: rgba(17, 28, 68, 0.6);
            border-radius: 24px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(20px);
        }
        h1 { color: #00D9FF; margin-bottom: 1rem; }
        p { color: #A0AEC0; line-height: 1.6; }
        .spinner {
            width: 50px;
            height: 50px;
            margin: 2rem auto;
            border: 4px solid rgba(0, 217, 255, 0.2);
            border-top: 4px solid #00D9FF;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
    <script>
        // Auto-reload after 3 seconds
        setTimeout(() => window.location.reload(), 3000);
    </script>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h1>Services Starting Up</h1>
        <p>Local AI Studio is initializing. This usually takes 5-10 seconds.</p>
        <p>This page will automatically refresh in 3 seconds...</p>
    </div>
</body>
</html>';
    }

    # Access logs
    access_log /var/log/nginx/localai.studio.access.log;
    error_log /var/log/nginx/localai.studio.error.log;
}
EOF

# Test nginx configuration
nginx -t

# If test passes, reload nginx
systemctl reload nginx
```

### Step 4: Fix JavaScript Scroll Function

Update the HTML file to fix the scrollToMarketplace function:

```bash
cd /root/localai-studio-marketplace

# Backup original
cp local-ai-studio-with-affiliates.html local-ai-studio-with-affiliates.html.backup

# Fix the scrollToMarketplace function
# Replace lines 1312-1318 with improved version
cat > /tmp/scroll_fix.js << 'EOF'
        // Scroll to marketplace section
        function scrollToMarketplace() {
            const messagesContainer = document.getElementById('messages');
            const marketplace = document.querySelector('.models-grid');

            if (messagesContainer && marketplace) {
                // Calculate position of marketplace within messages container
                const containerRect = messagesContainer.getBoundingClientRect();
                const marketplaceRect = marketplace.getBoundingClientRect();
                const scrollOffset = marketplaceRect.top - containerRect.top + messagesContainer.scrollTop;

                // Smooth scroll within messages container
                messagesContainer.scrollTo({
                    top: scrollOffset - 20, // 20px offset for padding
                    behavior: 'smooth'
                });
            } else {
                // Fallback: scroll to .models-section if marketplace not found
                const modelsSection = document.querySelector('.models-section');
                if (modelsSection) {
                    messagesContainer.scrollTo({
                        top: 0,
                        behavior: 'smooth'
                    });
                }
            }
        }
EOF

# Apply the fix using sed (replace lines 1312-1318)
# Note: This is complex with sed, so we'll use a Python script
python3 << 'PYTHON_EOF'
with open('/root/localai-studio-marketplace/local-ai-studio-with-affiliates.html', 'r') as f:
    lines = f.readlines()

# Find and replace the scrollToMarketplace function (lines 1312-1318, 0-indexed: 1311-1317)
new_function = '''        // Scroll to marketplace section
        function scrollToMarketplace() {
            const messagesContainer = document.getElementById('messages');
            const marketplace = document.querySelector('.models-grid');

            if (messagesContainer && marketplace) {
                // Calculate position of marketplace within messages container
                const containerRect = messagesContainer.getBoundingClientRect();
                const marketplaceRect = marketplace.getBoundingClientRect();
                const scrollOffset = marketplaceRect.top - containerRect.top + messagesContainer.scrollTop;

                // Smooth scroll within messages container
                messagesContainer.scrollTo({
                    top: scrollOffset - 20, // 20px offset for padding
                    behavior: 'smooth'
                });
            } else {
                // Fallback: scroll to .models-section if marketplace not found
                const modelsSection = document.querySelector('.models-section');
                if (modelsSection) {
                    messagesContainer.scrollTo({
                        top: 0,
                        behavior: 'smooth'
                    });
                }
            }
        }
'''

# Replace lines 1311-1317 (0-indexed)
lines[1311:1318] = [new_function + '\n']

# Write back
with open('/root/localai-studio-marketplace/local-ai-studio-with-affiliates.html', 'w') as f:
    f.writelines(lines)

print("✅ Fixed scrollToMarketplace function")
PYTHON_EOF
```

### Step 5: Restart Containers and Verify

```bash
cd /root/localai-studio-marketplace

# Stop containers
docker compose -f docker-compose.production.yml down

# Ensure data directories exist
mkdir -p /root/localai-studio-marketplace/data/backend
mkdir -p /root/localai-studio-marketplace/data/ollama

# Start containers with healthcheck monitoring
docker compose -f docker-compose.production.yml up -d

# Monitor healthchecks (wait 40 seconds for start_period)
echo "Waiting 40 seconds for backend startup period..."
sleep 40

# Check container health status
docker compose -f docker-compose.production.yml ps

# Expected output should show "(healthy)" for all services
# Example:
# NAME                        STATUS
# localai-backend            Up 45 seconds (healthy)
# localai-frontend           Up 45 seconds (healthy)
# localai-ollama             Up 45 seconds (healthy)

# Check logs for any errors
docker compose -f docker-compose.production.yml logs backend --tail 20
docker compose -f docker-compose.production.yml logs frontend --tail 20
```

### Step 6: Test Backend Health Endpoint

```bash
# Test backend health from host
curl -f http://127.0.0.1:8000/health
curl -f http://127.0.0.1:8000/api/health

# Test via nginx proxy
curl -f http://127.0.0.1/health
curl -f https://localai.studio/health

# Expected: {"status": "ok"} or similar
```

### Step 7: Test Frontend Access

```bash
# Test frontend directly
curl -I http://127.0.0.1:3000

# Test via nginx proxy
curl -I https://localai.studio

# Expected: HTTP/2 200 OK with proper headers
```

---

## VERIFICATION STEPS

### Test 1: 500 Error Fixed
1. Clear browser cache (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows/Linux)
2. Visit https://localai.studio in private/incognito window
3. Verify page loads successfully on first visit without 500 error
4. Check browser console (F12) for any errors

**Expected Result:** Page loads with blue gradient background immediately, no 500 error

### Test 2: Background Color Fixed
1. Refresh page multiple times (Cmd+R / Ctrl+R)
2. Verify blue gradient background appears immediately on every load
3. Check Network tab in browser DevTools - HTML should load with 200 status

**Expected Result:** Blue gradient background visible from first render, no white flash

### Test 3: Scroll Button Working
1. Click "💎 Buy More Models" button in header
2. Verify smooth scroll to marketplace section (model cards)
3. Test from different scroll positions

**Expected Result:** Smooth scroll to top of marketplace model grid

---

## DEBUGGING COMMANDS

### Check Nginx Error Logs
```bash
tail -f /var/log/nginx/localai.studio.error.log
```

### Check Nginx Access Logs
```bash
tail -f /var/log/nginx/localai.studio.access.log
```

### Check Container Logs (Real-time)
```bash
docker compose -f docker-compose.production.yml logs -f backend
docker compose -f docker-compose.production.yml logs -f frontend
docker compose -f docker-compose.production.yml logs -f ollama
```

### Check Docker Network
```bash
docker network inspect localai-network
```

### Test Backend API Directly
```bash
# Health check
curl -v http://127.0.0.1:8000/health

# Models endpoint
curl -v http://127.0.0.1:8000/api/models

# Chat endpoint (POST)
curl -X POST http://127.0.0.1:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "model": "tinyllama:latest"}'
```

### Check Ollama Connection
```bash
# From host
curl http://127.0.0.1:11434/api/tags

# From backend container
docker exec localai-backend curl http://host.docker.internal:11434/api/tags
```

---

## ROLLBACK PROCEDURE

If anything breaks:

### Rollback Nginx Config
```bash
cp /etc/nginx/sites-available/localai.studio.backup /etc/nginx/sites-available/localai.studio
nginx -t && systemctl reload nginx
```

### Rollback HTML File
```bash
cd /root/localai-studio-marketplace
cp local-ai-studio-with-affiliates.html.backup local-ai-studio-with-affiliates.html
docker compose -f docker-compose.production.yml restart frontend
```

### Rollback Container Changes
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.production.yml down
# Edit docker-compose.production.yml to revert changes
docker compose -f docker-compose.production.yml up -d
```

---

## PRODUCTION DEPLOYMENT CHECKLIST

After fixes are verified:

- [ ] 500 error on first load - RESOLVED
- [ ] Background color loads immediately - RESOLVED
- [ ] Scroll button works - RESOLVED
- [ ] Backend healthcheck passing
- [ ] Frontend healthcheck passing
- [ ] Ollama responding to requests
- [ ] SSL certificate valid and auto-renewing
- [ ] Nginx error logs clean
- [ ] All containers showing (healthy) status
- [ ] Browser console shows no errors
- [ ] Test purchase flow works
- [ ] Test chat functionality works
- [ ] Test model installation works

---

## ADDITIONAL OPTIMIZATIONS

### 1. Add Nginx Caching for Static Assets

```bash
# Add to nginx config http block
http {
    # ... existing config ...

    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=static_cache:10m max_size=1g inactive=60m;
    proxy_cache_key "$scheme$request_method$host$request_uri";

    # ... rest of config ...
}
```

### 2. Enable Gzip Compression

```bash
# Add to nginx http block
http {
    # ... existing config ...

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
    gzip_disable "msie6";
}
```

### 3. Add Rate Limiting

```bash
# Add to nginx http block
http {
    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=general_limit:10m rate=30r/s;

    # ... rest of config ...
}

# In server block, add to /api/ location:
location /api/ {
    limit_req zone=api_limit burst=20 nodelay;
    # ... existing proxy config ...
}
```

---

## MONITORING AND ALERTING

### Setup Basic Monitoring

```bash
# Install monitoring tools
apt update && apt install -y htop iotop nethogs

# Create monitoring script
cat > /root/monitor-localai.sh << 'EOF'
#!/bin/bash
echo "=== Local AI Studio Monitoring ==="
echo ""
echo "1. Container Status:"
docker compose -f /root/localai-studio-marketplace/docker-compose.production.yml ps
echo ""
echo "2. Container Health:"
docker inspect --format='{{.Name}}: {{.State.Health.Status}}' $(docker ps -q)
echo ""
echo "3. Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo ""
echo "4. Recent Nginx Errors:"
tail -5 /var/log/nginx/localai.studio.error.log
echo ""
echo "5. Recent Backend Logs:"
docker logs localai-backend --tail 5
EOF

chmod +x /root/monitor-localai.sh

# Run monitoring
/root/monitor-localai.sh
```

### Setup Cron Job for Regular Checks

```bash
# Add health check cron job
crontab -e

# Add this line:
*/5 * * * * curl -f https://localai.studio/health > /dev/null 2>&1 || echo "Health check failed at $(date)" >> /root/healthcheck.log
```

---

## CONTACT AND SUPPORT

**VPS Details:**
- IP: 31.220.109.75
- Site: https://localai.studio
- SSH: Via Terminus app
- Project: /root/localai-studio-marketplace/

**Key Files:**
- HTML: `/root/localai-studio-marketplace/local-ai-studio-with-affiliates.html`
- Docker Compose: `/root/localai-studio-marketplace/docker-compose.production.yml`
- Nginx Config: `/etc/nginx/sites-available/localai.studio`
- Backend: `/root/localai-studio-marketplace/backend/main.py` (inside container)

**Useful Commands:**
```bash
# Quick status check
cd /root/localai-studio-marketplace && docker compose -f docker-compose.production.yml ps

# Quick restart
cd /root/localai-studio-marketplace && docker compose -f docker-compose.production.yml restart

# View all logs
cd /root/localai-studio-marketplace && docker compose -f docker-compose.production.yml logs -f

# Emergency stop
cd /root/localai-studio-marketplace && docker compose -f docker-compose.production.yml down

# Full restart
cd /root/localai-studio-marketplace && docker compose -f docker-compose.production.yml down && docker compose -f docker-compose.production.yml up -d
```

---

**END OF DIAGNOSTIC GUIDE**
Generated: 2025-11-17
