#!/bin/bash
# Local AI Studio Marketplace - Quick Fix Script
# Run this on VPS: bash fix-all-issues.sh

set -e  # Exit on any error

echo "=========================================="
echo "Local AI Studio - Fix All Issues"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_DIR="/root/localai-studio-marketplace"
cd "$PROJECT_DIR"

echo -e "${YELLOW}Step 1: Backup Current Configuration${NC}"
echo "Creating backups..."
cp local-ai-studio-with-affiliates.html local-ai-studio-with-affiliates.html.backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
cp /etc/nginx/sites-available/localai.studio /etc/nginx/sites-available/localai.studio.backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
echo -e "${GREEN}✓ Backups created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Fix JavaScript Scroll Function${NC}"
echo "Updating scrollToMarketplace() function..."

python3 << 'PYTHON_EOF'
import sys

try:
    with open('/root/localai-studio-marketplace/local-ai-studio-with-affiliates.html', 'r') as f:
        content = f.read()

    # Find and replace the scrollToMarketplace function
    old_function = '''        // Scroll to marketplace section
        function scrollToMarketplace() {
            const marketplace = document.querySelector('.models-grid');
            if (marketplace) {
                marketplace.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }'''

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
                if (modelsSection && messagesContainer) {
                    messagesContainer.scrollTo({
                        top: 0,
                        behavior: 'smooth'
                    });
                }
            }
        }'''

    if old_function in content:
        content = content.replace(old_function, new_function)
        with open('/root/localai-studio-marketplace/local-ai-studio-with-affiliates.html', 'w') as f:
            f.write(content)
        print("✓ Fixed scrollToMarketplace function")
    else:
        print("⚠ Function already updated or not found in expected format")
        sys.exit(0)  # Not a fatal error

except Exception as e:
    print(f"✗ Error updating HTML: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ JavaScript scroll function fixed${NC}"
else
    echo -e "${RED}✗ Failed to fix JavaScript${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 3: Update Nginx Configuration${NC}"
echo "Creating improved nginx config with retry logic..."

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

    # Client settings
    client_max_body_size 100M;
    client_body_timeout 300s;

    # Timeouts for backend startup
    proxy_connect_timeout 90s;
    proxy_send_timeout 90s;
    proxy_read_timeout 90s;

    # Backend API with retry logic
    location /api/ {
        error_page 502 503 504 = @backend_down;

        proxy_pass http://backend_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Retry logic
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://backend_api/health;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        access_log off;
    }

    # Frontend
    location / {
        # Cache static assets
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            proxy_pass http://frontend_app;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
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

        # No caching for HTML
        add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    }

    # Backend down fallback
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

    # Logs
    access_log /var/log/nginx/localai.studio.access.log;
    error_log /var/log/nginx/localai.studio.error.log;
}
EOF

# Test nginx configuration
if nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Nginx configuration valid${NC}"
    systemctl reload nginx
    echo -e "${GREEN}✓ Nginx reloaded${NC}"
else
    echo -e "${RED}✗ Nginx configuration test failed${NC}"
    echo "Restoring backup..."
    cp /etc/nginx/sites-available/localai.studio.backup-* /etc/nginx/sites-available/localai.studio 2>/dev/null || true
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 4: Check Backend Health Endpoint${NC}"
echo "Testing backend health endpoints..."

# Check if containers are running
if ! docker compose -f docker-compose.production.yml ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠ Containers not running. Starting them first...${NC}"
    mkdir -p /root/localai-studio-marketplace/data/backend
    mkdir -p /root/localai-studio-marketplace/data/ollama
    docker compose -f docker-compose.production.yml up -d
    echo "Waiting 45 seconds for startup..."
    sleep 45
fi

# Test health endpoint
if docker exec localai-backend curl -f http://localhost:8000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend /health endpoint responding${NC}"
elif docker exec localai-backend curl -f http://localhost:8000/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend /api/health endpoint responding${NC}"
    echo -e "${YELLOW}⚠ Note: Health endpoint is at /api/health, updating docker-compose...${NC}"

    # Update docker-compose.yml healthcheck
    sed -i 's|http://localhost:8000/health|http://localhost:8000/api/health|g' docker-compose.production.yml
    echo -e "${GREEN}✓ Updated healthcheck endpoint${NC}"
else
    echo -e "${YELLOW}⚠ Backend health endpoint not responding yet${NC}"
    echo "This is normal during first startup. Continuing..."
fi
echo ""

echo -e "${YELLOW}Step 5: Restart Containers${NC}"
echo "Restarting all containers to apply changes..."

docker compose -f docker-compose.production.yml restart frontend
echo "Waiting for containers to be healthy (45 seconds)..."
sleep 45

echo ""
echo -e "${YELLOW}Step 6: Verify Services${NC}"

# Check container status
echo "Container Status:"
docker compose -f docker-compose.production.yml ps
echo ""

# Check health
echo "Health Checks:"
HEALTH_STATUS=$(docker inspect --format='{{.Name}}: {{.State.Health.Status}}' $(docker ps -q 2>/dev/null) 2>/dev/null || echo "No health info")
echo "$HEALTH_STATUS"
echo ""

# Test frontend
echo "Testing frontend..."
if curl -f -s http://127.0.0.1:3000 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Frontend responding on port 3000${NC}"
else
    echo -e "${RED}✗ Frontend not responding${NC}"
fi

# Test backend
echo "Testing backend..."
if curl -f -s http://127.0.0.1:8000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend responding on port 8000${NC}"
elif curl -f -s http://127.0.0.1:8000/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend responding on port 8000 (at /api/health)${NC}"
else
    echo -e "${YELLOW}⚠ Backend not responding yet (may need more time)${NC}"
fi

# Test public HTTPS
echo "Testing public site..."
if curl -f -s https://localai.studio >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Public site responding at https://localai.studio${NC}"
else
    echo -e "${YELLOW}⚠ Public site not responding yet${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}FIX SCRIPT COMPLETED${NC}"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Clear browser cache (Cmd+Shift+R / Ctrl+Shift+R)"
echo "2. Visit https://localai.studio in incognito/private window"
echo "3. Test the following:"
echo "   - Page loads without 500 error"
echo "   - Blue background appears immediately"
echo "   - Click '💎 Buy More Models' button - should scroll smoothly"
echo ""
echo "If issues persist, check logs:"
echo "  docker compose -f docker-compose.production.yml logs -f"
echo "  tail -f /var/log/nginx/localai.studio.error.log"
echo ""
echo "To rollback changes, run:"
echo "  bash rollback-fixes.sh"
echo ""
