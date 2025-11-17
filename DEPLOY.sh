#!/bin/bash
# Local AI Studio Marketplace - One-Command VPS Deployment
# Run this on your Hostinger VPS (31.220.109.75) via Terminus

set -e

echo "🚀 Local AI Studio Marketplace - VPS Deployment"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "❌ Please run as root"
   exit 1
fi

# Clone or update repository
if [ -d "/root/localai-studio-marketplace" ]; then
    echo "📥 Updating existing repository..."
    cd /root/localai-studio-marketplace
    git pull origin main
else
    echo "📥 Cloning repository..."
    cd /root
    git clone https://github.com/woodman33/localai-studio-marketplace.git
    cd localai-studio-marketplace
fi

# Create data directories
echo "📁 Creating data directories..."
mkdir -p /root/localai-studio-marketplace/data/backend
chmod 755 /root/localai-studio-marketplace/data
chmod 755 /root/localai-studio-marketplace/data/backend

# Create environment file
echo "⚙️  Creating environment configuration..."
cat > .env << 'EOF'
SKIP_PAYMENT=true
STRIPE_SECRET_KEY=sk_test_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
OLLAMA_BASE_URL=http://host.docker.internal:11434
FRONTEND_URL=https://localai.studio
EOF

# Check if Open WebUI is running
echo "🔍 Checking existing services..."
if docker ps | grep -q open-webui; then
    echo "✅ Open WebUI detected on port 3000"
else
    echo "⚠️  Warning: Open WebUI not detected"
fi

if docker ps | grep -q ollama; then
    echo "✅ Ollama detected on port 11434"
else
    echo "⚠️  Warning: Ollama not detected - will use marketplace Ollama"
fi

# Stop any existing marketplace containers
echo "🛑 Stopping old marketplace containers..."
docker compose -f docker-compose.production.yml down 2>/dev/null || true

# Build and start services
echo "🏗️  Building marketplace images..."
docker compose -f docker-compose.production.yml build --no-cache

echo "🚀 Starting marketplace services..."
docker compose -f docker-compose.production.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to start..."
sleep 15

# Check container status
echo ""
echo "📊 Container Status:"
docker compose -f docker-compose.production.yml ps

# Test backend health
echo ""
echo "🏥 Testing backend health..."
if curl -f http://localhost:8000/health 2>/dev/null; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend health check failed"
fi

# Test frontend
echo ""
echo "🌐 Testing frontend..."
if curl -f http://localhost:3000 2>/dev/null; then
    echo "✅ Frontend is accessible"
else
    echo "❌ Frontend not accessible"
fi

# Configure Nginx reverse proxy
echo ""
echo "🔧 Configuring Nginx reverse proxy..."

# Install Nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing Nginx..."
    apt update
    apt install -y nginx
fi

# Install Certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing Certbot..."
    apt install -y certbot python3-certbot-nginx
fi

# Create Nginx configuration
cat > /etc/nginx/sites-available/localai.studio << 'NGINX_EOF'
upstream localai_backend {
    server 127.0.0.1:8000;
    keepalive 32;
}

upstream localai_frontend {
    server 127.0.0.1:3000;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name localai.studio www.localai.studio;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Frontend
    location / {
        proxy_pass http://localai_frontend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api/ {
        proxy_pass http://localai_backend/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}
NGINX_EOF

# Enable site
ln -sf /etc/nginx/sites-available/localai.studio /etc/nginx/sites-enabled/

# Test Nginx configuration
if nginx -t; then
    echo "✅ Nginx configuration valid"
    systemctl reload nginx
else
    echo "❌ Nginx configuration invalid"
    exit 1
fi

# Setup SSL certificate
echo ""
echo "🔒 Setting up SSL certificate..."
if certbot --nginx -d localai.studio -d www.localai.studio --non-interactive --agree-tos -m admin@localai.studio --redirect 2>&1 | grep -q "Successfully"; then
    echo "✅ SSL certificate obtained"
else
    echo "⚠️  SSL setup skipped (may already exist or domain not pointed)"
fi

# Final status
echo ""
echo "================================================"
echo "✨ DEPLOYMENT COMPLETE!"
echo "================================================"
echo ""
echo "🌐 Your marketplace is now available at:"
echo "   https://localai.studio"
echo ""
echo "🔧 Services running:"
docker compose -f docker-compose.production.yml ps
echo ""
echo "📝 Next steps:"
echo "1. Visit https://localai.studio in your browser"
echo "2. Test the AI chat with free TinyLlama model"
echo "3. Try purchasing a model (test mode - no charge)"
echo ""
echo "📊 View logs:"
echo "   cd /root/localai-studio-marketplace"
echo "   docker compose -f docker-compose.production.yml logs -f"
echo ""
echo "🔄 Restart services:"
echo "   docker compose -f docker-compose.production.yml restart"
echo ""
