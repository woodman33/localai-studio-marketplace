#!/bin/bash

#################################################
# Local AI Studio Marketplace - Deployment Verification
# Run after deployment to verify all services
#################################################

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Deployment Verification"
echo "=========================================="
echo ""

# Check 1: Docker containers
echo -e "${YELLOW}[1/8] Checking Docker containers...${NC}"
BACKEND_STATUS=$(docker inspect -f '{{.State.Status}}' localai-marketplace-backend 2>/dev/null || echo "not found")
FRONTEND_STATUS=$(docker inspect -f '{{.State.Status}}' localai-marketplace-frontend 2>/dev/null || echo "not found")
OPENWEBUI_STATUS=$(docker inspect -f '{{.State.Status}}' open-webui 2>/dev/null || echo "not found")
OLLAMA_STATUS=$(docker inspect -f '{{.State.Status}}' ollama 2>/dev/null || echo "not found")

if [ "$BACKEND_STATUS" == "running" ]; then
    echo -e "${GREEN}✓ Marketplace Backend: running${NC}"
else
    echo -e "${RED}✗ Marketplace Backend: $BACKEND_STATUS${NC}"
fi

if [ "$FRONTEND_STATUS" == "running" ]; then
    echo -e "${GREEN}✓ Marketplace Frontend: running${NC}"
else
    echo -e "${RED}✗ Marketplace Frontend: $FRONTEND_STATUS${NC}"
fi

if [ "$OPENWEBUI_STATUS" == "running" ]; then
    echo -e "${GREEN}✓ Open WebUI: running${NC}"
else
    echo -e "${RED}✗ Open WebUI: $OPENWEBUI_STATUS${NC}"
fi

if [ "$OLLAMA_STATUS" == "running" ]; then
    echo -e "${GREEN}✓ Ollama: running${NC}"
else
    echo -e "${RED}✗ Ollama: $OLLAMA_STATUS${NC}"
fi
echo ""

# Check 2: Port availability
echo -e "${YELLOW}[2/8] Checking port bindings...${NC}"
if netstat -tuln | grep -q ":3000 "; then
    echo -e "${GREEN}✓ Port 3000: Open WebUI listening${NC}"
else
    echo -e "${RED}✗ Port 3000: Not listening${NC}"
fi

if netstat -tuln | grep -q ":3001 "; then
    echo -e "${GREEN}✓ Port 3001: Marketplace Frontend listening${NC}"
else
    echo -e "${RED}✗ Port 3001: Not listening${NC}"
fi

if netstat -tuln | grep -q ":8000 "; then
    echo -e "${GREEN}✓ Port 8000: Marketplace Backend listening${NC}"
else
    echo -e "${RED}✗ Port 8000: Not listening${NC}"
fi

if netstat -tuln | grep -q ":11434 "; then
    echo -e "${GREEN}✓ Port 11434: Ollama listening${NC}"
else
    echo -e "${RED}✗ Port 11434: Not listening${NC}"
fi
echo ""

# Check 3: Backend health
echo -e "${YELLOW}[3/8] Checking backend health endpoint...${NC}"
BACKEND_HEALTH=$(curl -sf http://localhost:8000/health 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backend health check: OK${NC}"
    echo "  Response: $BACKEND_HEALTH"
else
    echo -e "${RED}✗ Backend health check: FAILED${NC}"
    echo "  Error: $BACKEND_HEALTH"
fi
echo ""

# Check 4: Frontend accessibility
echo -e "${YELLOW}[4/8] Checking frontend accessibility...${NC}"
FRONTEND_CHECK=$(curl -sf http://localhost:3001 | head -c 100)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Frontend accessible${NC}"
else
    echo -e "${RED}✗ Frontend not accessible${NC}"
fi
echo ""

# Check 5: Ollama connectivity
echo -e "${YELLOW}[5/8] Checking Ollama connectivity...${NC}"
OLLAMA_CHECK=$(curl -sf http://localhost:11434/api/tags 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Ollama API accessible${NC}"
    echo "  Models: $(echo $OLLAMA_CHECK | jq -r '.models[].name' | head -3 | tr '\n' ', ' | sed 's/,$//')"
else
    echo -e "${RED}✗ Ollama API not accessible${NC}"
fi
echo ""

# Check 6: Nginx configuration
echo -e "${YELLOW}[6/8] Checking Nginx configuration...${NC}"
if nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Nginx configuration valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration invalid${NC}"
fi

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx service active${NC}"
else
    echo -e "${RED}✗ Nginx service inactive${NC}"
fi
echo ""

# Check 7: SSL certificate
echo -e "${YELLOW}[7/8] Checking SSL certificate...${NC}"
if [ -f /etc/letsencrypt/live/localai.studio/fullchain.pem ]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/localai.studio/fullchain.pem | cut -d= -f2)
    echo -e "${GREEN}✓ SSL certificate exists${NC}"
    echo "  Expires: $CERT_EXPIRY"
else
    echo -e "${RED}✗ SSL certificate not found${NC}"
fi
echo ""

# Check 8: Database file
echo -e "${YELLOW}[8/8] Checking database...${NC}"
if [ -f /root/localai-studio-marketplace/data/backend/purchases.db ]; then
    DB_SIZE=$(du -h /root/localai-studio-marketplace/data/backend/purchases.db | cut -f1)
    echo -e "${GREEN}✓ Database file exists${NC}"
    echo "  Location: /root/localai-studio-marketplace/data/backend/purchases.db"
    echo "  Size: $DB_SIZE"
else
    echo -e "${YELLOW}⚠ Database not yet created (will be created on first purchase)${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "VERIFICATION SUMMARY"
echo "=========================================="
echo ""
echo -e "${GREEN}Test URLs:${NC}"
echo "  Marketplace: https://localai.studio"
echo "  Backend Health: http://localhost:8000/health"
echo "  Frontend Local: http://localhost:3001"
echo "  Open WebUI: http://31.220.109.75:3000"
echo ""
echo -e "${GREEN}Quick Tests:${NC}"
echo "  curl http://localhost:8000/health"
echo "  curl http://localhost:3001"
echo "  curl http://localhost:11434/api/tags"
echo "  docker compose -f /root/localai-studio-marketplace/docker-compose.vps.yml ps"
echo ""
echo -e "${GREEN}Logs:${NC}"
echo "  docker compose -f /root/localai-studio-marketplace/docker-compose.vps.yml logs -f backend"
echo "  docker compose -f /root/localai-studio-marketplace/docker-compose.vps.yml logs -f frontend"
echo "  tail -f /var/log/nginx/localai.studio.access.log"
echo "  tail -f /var/log/nginx/localai.studio.error.log"
echo ""
