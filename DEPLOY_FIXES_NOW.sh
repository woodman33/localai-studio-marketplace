#!/bin/bash
# SIMPLE VPS DEPLOYMENT SCRIPT
# Fixes: Dropdown text visibility + Buy More Models button
# Run this on VPS: bash DEPLOY_FIXES_NOW.sh

set -e

echo "=========================================="
echo "DEPLOYING UI FIXES TO LOCAL AI STUDIO"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /root/localai-studio-marketplace

echo -e "${YELLOW}Step 1: Discard local changes${NC}"
git checkout -- local-ai-studio-with-affiliates.html
echo -e "${GREEN}✓ Local changes discarded${NC}"
echo ""

echo -e "${YELLOW}Step 2: Pull latest code from GitHub${NC}"
git pull origin main
echo -e "${GREEN}✓ Latest code pulled${NC}"
echo ""

echo -e "${YELLOW}Step 3: Verify dropdown fix is present${NC}"
if grep -q "background: #1e293b; color: #ffffff" local-ai-studio-with-affiliates.html; then
    echo -e "${GREEN}✓ Dropdown inline styles found${NC}"
else
    echo -e "${RED}✗ ERROR: Dropdown fix not found in file${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 4: Verify scroll fix is present${NC}"
if grep -q "messagesContainer.scrollTo" local-ai-studio-with-affiliates.html; then
    echo -e "${GREEN}✓ Scroll function fix found${NC}"
else
    echo -e "${RED}✗ ERROR: Scroll fix not found in file${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 5: Recreate frontend container${NC}"
docker compose -f docker-compose.production.yml stop frontend
docker compose -f docker-compose.production.yml rm -f frontend
docker compose -f docker-compose.production.yml up -d frontend
echo -e "${GREEN}✓ Frontend container recreated${NC}"
echo ""

echo -e "${YELLOW}Step 6: Wait for container to be ready${NC}"
sleep 5
echo -e "${GREEN}✓ Container should be ready${NC}"
echo ""

echo -e "${YELLOW}Step 7: Verify new file is mounted in container${NC}"
if docker exec localai-frontend grep -q "background: #1e293b" /usr/share/nginx/html/marketplace.html; then
    echo -e "${GREEN}✓ New file is mounted correctly${NC}"
else
    echo -e "${RED}✗ ERROR: Container still has old file${NC}"
    echo "Try: docker compose -f docker-compose.production.yml down"
    echo "Then: docker compose -f docker-compose.production.yml up -d"
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 8: Check container status${NC}"
docker compose -f docker-compose.production.yml ps frontend
echo ""

echo "=========================================="
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo "=========================================="
echo ""
echo "✅ Dropdown text should now be WHITE on DARK background"
echo "✅ Buy More Models button should scroll to marketplace"
echo ""
echo "🌐 TEST NOW:"
echo "1. Visit https://localai.studio"
echo "2. Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)"
echo "3. Check dropdown menus in model cards"
echo "4. Click 'Buy More Models' button in header"
echo ""
echo "If you still see issues:"
echo "- Try incognito/private window"
echo "- Clear all browser cache"
echo "- Check browser console for errors (F12)"
echo ""
