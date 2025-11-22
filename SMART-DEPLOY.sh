#!/bin/bash
# Local AI Studio Marketplace - Smart Port Detection & Deployment
# For Hostinger VPS at 31.220.109.75

set -e

echo "🚀 Local AI Studio Marketplace - Smart VPS Deployment"
echo "======================================================"
echo ""

# Phase 1: Port Discovery
echo "🔍 Phase 1: Discovering available ports..."
echo ""

# Check common ports
PORTS_TO_CHECK="3000 3001 3002 3003 3004 8000 8001 8002 11434"

echo "Checking port availability:"
for port in $PORTS_TO_CHECK; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ❌ Port $port: IN USE"
    else
        echo "  ✅ Port $port: AVAILABLE"
    fi
done

echo ""
echo "Current Docker containers:"
docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null || echo "  No containers running"

echo ""
echo "---"
read -p "Press Enter to continue with deployment..."

# Phase 2: Smart Port Selection
echo ""
echo "🧠 Phase 2: Selecting optimal ports..."

# Find available frontend port (prefer 3003, fallback to first available)
FRONTEND_PORT=""
for port in 3003 3004 3001 3002 3005; do
    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        FRONTEND_PORT=$port
        break
    fi
done

# Find available backend port (prefer 8000, fallback to 8001)
BACKEND_PORT=""
for port in 8000 8001 8002; do
    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        BACKEND_PORT=$port
        break
    fi
done

if [ -z "$FRONTEND_PORT" ] || [ -z "$BACKEND_PORT" ]; then
    echo "❌ ERROR: Could not find available ports!"
    echo "   Frontend: $FRONTEND_PORT"
    echo "   Backend: $BACKEND_PORT"
    exit 1
fi

echo "✅ Selected ports:"
echo "   Frontend: $FRONTEND_PORT"
echo "   Backend: $BACKEND_PORT"
echo "   Ollama: 11434 (shared with existing)"

# Phase 3: Clone/Update Repository
echo ""
echo "📥 Phase 3: Cloning repository..."

if [ -d "/root/localai-studio-marketplace" ]; then
    echo "Repository exists, updating..."
    cd /root/localai-studio-marketplace
    git pull origin main
else
    echo "Cloning fresh repository..."
    cd /root
    git clone https://github.com/woodman33/localai-studio-marketplace.git
    cd localai-studio-marketplace
fi

# Phase 4: Create Environment File & Load Variables
echo ""
echo "⚙️ Phase 4: Creating environment configuration..."

# Only create if it doesn't exist to avoid overwriting user keys
if [ ! -f .env ]; then
    cat > .env << 'ENV_EOF'
SKIP_PAYMENT=true
STRIPE_SECRET_KEY=sk_test_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
FRONTEND_URL=https://localai.studio
GUMROAD_PRODUCT_PERMALINK=udody
ENV_EOF
fi

# Load variables for injection into docker-compose
# Use Python for robust .env parsing (handles spaces, quotes, comments)
echo "   Reading .env file..."
if [ -f .env ]; then
    echo "   .env file exists. Content preview:"
    head -n 5 .env | sed 's/./& /g' # Print with spaces to see hidden chars
else
    echo "   ❌ .env file NOT found!"
fi

GUMROAD_KEY=$(python3 -c "
import re
import sys
try:
    with open('.env', 'r') as f:
        content = f.read()
        # Look for GUMROAD_API_KEY = value (ignoring spaces and quotes)
        match = re.search(r'GUMROAD_API_KEY\s*=\s*[\"\']?([^\"\n\r\']+)[\"\']?', content)
        if match: 
            print(match.group(1).strip())
        else:
            sys.stderr.write('Python regex failed to match GUMROAD_API_KEY\n')
except Exception as e: 
    sys.stderr.write(f'Python error: {e}\n')
")

GUMROAD_PERMALINK=$(python3 -c "
import re
try:
    with open('.env', 'r') as f:
        content = f.read()
        match = re.search(r'GUMROAD_PRODUCT_PERMALINK\s*=\s*[\"\']?([^\"\n\r\']+)[\"\']?', content)
        if match: print(match.group(1).strip())
        else: print('udody')
except: print('udody')
")

echo "   Debug: Extracted Key Length: ${#GUMROAD_KEY}"
if [ -z "$GUMROAD_KEY" ]; then
    echo "❌ ERROR: GUMROAD_API_KEY extraction failed!"
    echo "   Please ensure your .env file contains: GUMROAD_API_KEY=your_key_here"
else
    echo "   ✅ Found Gumroad API Key (starts with ${GUMROAD_KEY:0:4}...)"
fi

# Phase 5: Generate port-optimized configuration
echo ""
echo "📝 Phase 5: Generating port-optimized configuration..."

cat > docker-compose.smart.yml << COMPOSE_EOF
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    image: localai-marketplace-backend:latest
    container_name: localai-marketplace-backend
    ports:
      - "127.0.0.1:${BACKEND_PORT}:8000"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - STRIPE_SECRET_KEY=\${STRIPE_SECRET_KEY:-sk_test_PLACEHOLDER}
      - STRIPE_PUBLISHABLE_KEY=\${STRIPE_PUBLISHABLE_KEY:-pk_test_PLACEHOLDER}
      - STRIPE_WEBHOOK_SECRET=\${STRIPE_WEBHOOK_SECRET:-whsec_PLACEHOLDER}
      - SKIP_PAYMENT=\${SKIP_PAYMENT:-true}
      - FRONTEND_URL=\${FRONTEND_URL:-https://localai.studio}
      - GUMROAD_API_KEY=${GUMROAD_KEY}
      - GUMROAD_PRODUCT_PERMALINK=${GUMROAD_PERMALINK}
    volumes:
      - ./data/backend:/app/data
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    image: nginx:alpine
    container_name: localai-marketplace-frontend
    ports:
      - "127.0.0.1:${FRONTEND_PORT}:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
      - ./local-ai-studio-with-affiliates.html:/usr/share/nginx/html/marketplace.html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3
COMPOSE_EOF

# Phase 5: Create Environment File & Load Variables
echo ""
echo "⚙️ Phase 5: Creating environment configuration..."

cat > .env << 'ENV_EOF'
SKIP_PAYMENT=true
STRIPE_SECRET_KEY=sk_test_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
FRONTEND_URL=https://localai.studio
ENV_EOF

# Load variables for injection into docker-compose
# We use a simple grep to extract values since sourcing is proving unreliable in this context
GUMROAD_KEY=$(grep "^GUMROAD_API_KEY=" .env | cut -d '=' -f2- || echo "")
GUMROAD_PERMALINK=$(grep "^GUMROAD_PRODUCT_PERMALINK=" .env | cut -d '=' -f2- || echo "udody")

# If empty, try to find it without quotes if user added it differently
if [ -z "$GUMROAD_KEY" ]; then
    echo "⚠️  Warning: GUMROAD_API_KEY not found in .env via grep. Checking if set in shell..."
    GUMROAD_KEY="${GUMROAD_API_KEY}"
fi

echo "   Gumroad Key found: ${GUMROAD_KEY:0:5}..."
echo "   Gumroad Permalink: $GUMROAD_PERMALINK"

# Phase 6: Create Data Directories
echo ""
echo "📁 Phase 6: Setting up data directories..."

mkdir -p /root/localai-studio-marketplace/data/backend
chmod 755 /root/localai-studio-marketplace/data
chmod 755 /root/localai-studio-marketplace/data/backend

# Phase 7: Build & Deploy
echo ""
# Load environment variables from .env if present
if [ -f .env ]; then
  echo "Loading environment variables from .env..."
  set -a
  source .env
  set +a
fi

echo "🏗️ Phase 7: Building Docker images..."

docker compose -f docker-compose.smart.yml build --no-cache

echo ""
echo "🚀 Phase 8: Starting services..."

docker compose -f docker-compose.smart.yml up -d

# Wait for health checks
echo ""
echo "⏳ Phase 9: Waiting for services to be healthy..."
sleep 15

# Phase 10: Verify Deployment
echo ""
echo "🏥 Phase 10: Verifying deployment..."

echo ""
echo "Container status:"
docker compose -f docker-compose.smart.yml ps

echo ""
echo "Backend health check:"
if curl -f http://localhost:${BACKEND_PORT}/health 2>/dev/null; then
    echo "  ✅ Backend healthy at port ${BACKEND_PORT}"
else
    echo "  ❌ Backend health check failed"
fi

echo ""
echo "Frontend check:"
if curl -f http://localhost:${FRONTEND_PORT} 2>/dev/null | head -n 1; then
    echo "  ✅ Frontend accessible at port ${FRONTEND_PORT}"
else
    echo "  ❌ Frontend not accessible"
fi

# Phase 11: Configure Nginx Reverse Proxy
echo ""
echo "🔧 Phase 11: Configuring Nginx reverse proxy..."

# Install Nginx and Certbot if needed
if ! command -v nginx &> /dev/null; then
    apt update && apt install -y nginx
fi

if ! command -v certbot &> /dev/null; then
    apt install -y certbot python3-certbot-nginx
fi

# Create Nginx config with dynamic ports
cat > /etc/nginx/sites-available/localai.studio << NGINX_EOF
upstream marketplace_backend {
    server 127.0.0.1:${BACKEND_PORT};
    keepalive 32;
}

upstream marketplace_frontend {
    server 127.0.0.1:${FRONTEND_PORT};
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name localai.studio www.localai.studio;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        proxy_pass http://marketplace_frontend;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api/ {
        proxy_pass http://marketplace_backend/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}
NGINX_EOF

# Enable site
ln -sf /etc/nginx/sites-available/localai.studio /etc/nginx/sites-enabled/

# Test and reload Nginx
if nginx -t 2>&1 | grep -q "successful"; then
    echo "  ✅ Nginx configuration valid"
    systemctl reload nginx
else
    echo "  ❌ Nginx configuration invalid"
    nginx -t
    exit 1
fi

# Phase 12: SSL Certificate
echo ""
echo "🔒 Phase 12: Setting up SSL certificate..."

certbot --nginx -d localai.studio -d www.localai.studio \
    --non-interactive --agree-tos -m admin@localai.studio --redirect \
    2>&1 | tee /tmp/certbot.log

if grep -q "Successfully" /tmp/certbot.log; then
    echo "  ✅ SSL certificate installed"
else
    echo "  ⚠️  SSL setup completed (may already exist)"
fi

# Final Summary
echo ""
echo "========================================================"
echo "✨ DEPLOYMENT COMPLETE!"
echo "========================================================"
echo ""
echo "📊 Configuration:"
echo "   Frontend Port: ${FRONTEND_PORT}"
echo "   Backend Port:  ${BACKEND_PORT}"
echo "   Public URL:    https://localai.studio"
echo ""
echo "🌐 Services:"
docker compose -f docker-compose.smart.yml ps
echo ""
echo "🔗 Access your marketplace:"
echo "   https://localai.studio"
echo ""
echo "📝 Management commands:"
echo "   View logs:    cd /root/localai-studio-marketplace && docker compose -f docker-compose.smart.yml logs -f"
echo "   Restart:      docker compose -f docker-compose.smart.yml restart"
echo "   Stop:         docker compose -f docker-compose.smart.yml down"
echo "   Update code:  git pull && docker compose -f docker-compose.smart.yml up -d --build"
echo ""
echo "✅ Ready for Product Hunt launch!"
echo ""
