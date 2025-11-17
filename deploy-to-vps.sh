#!/bin/bash

#################################################
# Local AI Studio Marketplace - VPS Deployment Script
# Server: 31.220.109.75 (Hostinger VPS)
# Domain: localai.studio
# Execute via: Terminus SSH Terminal
#################################################

set -e  # Exit on error

echo "=========================================="
echo "Local AI Studio Marketplace Deployment"
echo "=========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Clone repository
echo -e "${YELLOW}[1/10] Cloning GitHub repository...${NC}"
cd /root
if [ -d "localai-studio-marketplace" ]; then
    echo "Directory exists, pulling latest changes..."
    cd localai-studio-marketplace
    git pull
else
    echo "Cloning fresh repository..."
    git clone https://github.com/woodman33/localai-studio-marketplace.git
    cd localai-studio-marketplace
fi
echo -e "${GREEN}✓ Repository ready${NC}"
echo ""

# Step 2: Create data directories
echo -e "${YELLOW}[2/10] Creating data directories...${NC}"
mkdir -p /root/localai-studio-marketplace/data/backend
chmod 755 /root/localai-studio-marketplace/data
chmod 755 /root/localai-studio-marketplace/data/backend
echo -e "${GREEN}✓ Data directories created${NC}"
echo ""

# Step 3: Create environment file
echo -e "${YELLOW}[3/10] Creating environment configuration...${NC}"
cat > /root/localai-studio-marketplace/.env << 'EOF'
# Local AI Studio Marketplace - VPS Configuration
SKIP_PAYMENT=true
STRIPE_SECRET_KEY=sk_test_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
OLLAMA_BASE_URL=http://host.docker.internal:11434
FRONTEND_URL=https://localai.studio
EOF
chmod 600 /root/localai-studio-marketplace/.env
echo -e "${GREEN}✓ Environment file created${NC}"
echo ""

# Step 4: Stop any existing marketplace containers
echo -e "${YELLOW}[4/10] Stopping existing marketplace containers...${NC}"
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml down 2>/dev/null || true
# Clean up old containers if they exist
docker rm -f localai-marketplace-backend 2>/dev/null || true
docker rm -f localai-marketplace-frontend 2>/dev/null || true
echo -e "${GREEN}✓ Old containers stopped${NC}"
echo ""

# Step 5: Verify Open WebUI is still running
echo -e "${YELLOW}[5/10] Verifying Open WebUI status...${NC}"
if docker ps | grep -q "open-webui"; then
    echo -e "${GREEN}✓ Open WebUI is running on port 3000${NC}"
else
    echo -e "${RED}⚠ Warning: Open WebUI is not running${NC}"
fi
if docker ps | grep -q "ollama"; then
    echo -e "${GREEN}✓ Ollama is running on port 11434${NC}"
else
    echo -e "${RED}⚠ Warning: Ollama is not running${NC}"
fi
echo ""

# Step 6: Build and start marketplace containers
echo -e "${YELLOW}[6/10] Building and starting marketplace containers...${NC}"
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml up -d --build
echo -e "${GREEN}✓ Marketplace containers started${NC}"
echo ""

# Step 7: Wait for services to be healthy
echo -e "${YELLOW}[7/10] Waiting for services to be healthy...${NC}"
sleep 10
for i in {1..30}; do
    if curl -sf http://localhost:8000/health > /dev/null; then
        echo -e "${GREEN}✓ Backend is healthy${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}⚠ Backend health check timeout${NC}"
    fi
    sleep 2
done

for i in {1..30}; do
    if curl -sf http://localhost:3001 > /dev/null; then
        echo -e "${GREEN}✓ Frontend is healthy${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}⚠ Frontend health check timeout${NC}"
    fi
    sleep 2
done
echo ""

# Step 8: Configure Nginx
echo -e "${YELLOW}[8/10] Configuring Nginx reverse proxy...${NC}"

# Backup existing config if it exists
if [ -f /etc/nginx/sites-available/localai.studio ]; then
    cp /etc/nginx/sites-available/localai.studio /etc/nginx/sites-available/localai.studio.backup.$(date +%Y%m%d%H%M%S)
    echo "Backed up existing Nginx config"
fi

# Copy new configuration
cp /root/localai-studio-marketplace/nginx-localai-studio.conf /etc/nginx/sites-available/localai.studio

# Enable site if not already enabled
if [ ! -L /etc/nginx/sites-enabled/localai.studio ]; then
    ln -s /etc/nginx/sites-available/localai.studio /etc/nginx/sites-enabled/localai.studio
    echo "Enabled Nginx site"
fi

# Test Nginx configuration
if nginx -t; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
    systemctl reload nginx
    echo -e "${GREEN}✓ Nginx reloaded${NC}"
else
    echo -e "${RED}✗ Nginx configuration has errors${NC}"
    exit 1
fi
echo ""

# Step 9: Setup SSL certificate (if not exists)
echo -e "${YELLOW}[9/10] Checking SSL certificate...${NC}"
if [ -f /etc/letsencrypt/live/localai.studio/fullchain.pem ]; then
    echo -e "${GREEN}✓ SSL certificate already exists${NC}"
    echo "Certificate expires: $(openssl x509 -enddate -noout -in /etc/letsencrypt/live/localai.studio/fullchain.pem)"
else
    echo -e "${YELLOW}Setting up new SSL certificate...${NC}"
    # Stop nginx temporarily
    systemctl stop nginx

    # Get certificate
    certbot certonly --standalone \
        -d localai.studio \
        -d www.localai.studio \
        --agree-tos \
        --non-interactive \
        --email admin@localai.studio

    # Start nginx
    systemctl start nginx
    echo -e "${GREEN}✓ SSL certificate installed${NC}"
fi
echo ""

# Step 10: Display status
echo -e "${YELLOW}[10/10] Deployment summary...${NC}"
echo ""
echo "=========================================="
echo "DEPLOYMENT SUMMARY"
echo "=========================================="
echo ""
echo -e "${GREEN}VPS Information:${NC}"
echo "  IP Address: 31.220.109.75"
echo "  Domain: localai.studio"
echo ""
echo -e "${GREEN}Services Status:${NC}"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "NAME|marketplace|open-webui|ollama"
echo ""
echo -e "${GREEN}Port Allocation:${NC}"
echo "  3000: Open WebUI (existing)"
echo "  3001: Marketplace Frontend (new)"
echo "  8000: Marketplace Backend (new)"
echo "  11434: Ollama (shared)"
echo ""
echo -e "${GREEN}Access URLs:${NC}"
echo "  Marketplace: https://localai.studio"
echo "  Open WebUI: http://31.220.109.75:3000"
echo "  Backend API: http://localhost:8000/health"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  SKIP_PAYMENT: true (test mode)"
echo "  SSL: $([ -f /etc/letsencrypt/live/localai.studio/fullchain.pem ] && echo 'Active' || echo 'Pending')"
echo "  Nginx: Active"
echo "  Firewall: $(ufw status | grep -o 'active\|inactive')"
echo ""
echo -e "${GREEN}Data Locations:${NC}"
echo "  Marketplace Data: /root/localai-studio-marketplace/data/backend"
echo "  Database: /root/localai-studio-marketplace/data/backend/purchases.db"
echo "  Logs: docker compose -f docker-compose.vps.yml logs"
echo ""
echo -e "${GREEN}Management Commands:${NC}"
echo "  View logs: cd /root/localai-studio-marketplace && docker compose -f docker-compose.vps.yml logs -f"
echo "  Restart: cd /root/localai-studio-marketplace && docker compose -f docker-compose.vps.yml restart"
echo "  Stop: cd /root/localai-studio-marketplace && docker compose -f docker-compose.vps.yml down"
echo "  Start: cd /root/localai-studio-marketplace && docker compose -f docker-compose.vps.yml up -d"
echo ""
echo "=========================================="
echo -e "${GREEN}✓ DEPLOYMENT COMPLETE${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Visit https://localai.studio to test the marketplace"
echo "2. Monitor logs: docker compose -f docker-compose.vps.yml logs -f"
echo "3. Open WebUI still accessible at http://31.220.109.75:3000"
echo ""
