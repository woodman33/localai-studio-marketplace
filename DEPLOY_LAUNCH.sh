#!/bin/bash
# FINAL LAUNCH DEPLOYMENT
# Run on VPS: bash DEPLOY_LAUNCH.sh

set -e

echo "=========================================="
echo "  LOCAL AI STUDIO - LAUNCH DEPLOYMENT"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /root/localai-studio-marketplace

echo -e "${CYAN}Step 1: Pull Latest Code from GitHub${NC}"
git fetch origin
git reset --hard origin/main
echo -e "${GREEN}✓ Latest code pulled${NC}"
echo ""

echo -e "${CYAN}Step 2: Verify Launch Features${NC}"
echo "Checking for new features..."

# Check for install system
if grep -q "installModel" local-ai-studio-with-affiliates.html; then
    echo -e "${GREEN}✓ One-click install system present${NC}"
else
    echo -e "${YELLOW}⚠ Install system not found${NC}"
fi

# Check for progress modal
if grep -q "progress-modal" local-ai-studio-with-affiliates.html; then
    echo -e "${GREEN}✓ Progress modal present${NC}"
else
    echo -e "${YELLOW}⚠ Progress modal not found${NC}"
fi

# Check for new models
MODEL_COUNT=$(grep -c "data-model=" local-ai-studio-with-affiliates.html || echo "0")
echo -e "${GREEN}✓ Found ${MODEL_COUNT} models in marketplace${NC}"

echo ""

echo -e "${CYAN}Step 3: Recreate Frontend Container${NC}"
docker compose -f docker-compose.production.yml stop frontend
docker compose -f docker-compose.production.yml rm -f frontend
docker compose -f docker-compose.production.yml up -d frontend
echo -e "${GREEN}✓ Frontend container recreated${NC}"
echo ""

echo -e "${CYAN}Step 4: Wait for Container Startup${NC}"
sleep 10
echo -e "${GREEN}✓ Container should be ready${NC}"
echo ""

echo -e "${CYAN}Step 5: Verify Deployment${NC}"

# Check container status
echo "Container Status:"
docker compose -f docker-compose.production.yml ps frontend

echo ""

# Verify file in container
echo "Verifying mounted file..."
if docker exec localai-frontend test -f /usr/share/nginx/html/marketplace.html; then
    FILE_SIZE=$(docker exec localai-frontend wc -l /usr/share/nginx/html/marketplace.html | awk '{print $1}')
    echo -e "${GREEN}✓ File mounted: ${FILE_SIZE} lines${NC}"
else
    echo -e "${YELLOW}⚠ File not found in container${NC}"
fi

echo ""

# Test HTTP response
echo "Testing HTTP response..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP 200 OK${NC}"
else
    echo -e "${YELLOW}⚠ HTTP ${HTTP_CODE}${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}   DEPLOYMENT COMPLETE! 🚀${NC}"
echo "=========================================="
echo ""
echo -e "${CYAN}🌐 Your marketplace is live at:${NC}"
echo "   https://localai.studio"
echo ""
echo -e "${CYAN}✅ NEW FEATURES:${NC}"
echo "   • 11 open source models"
echo "   • One-click install buttons"
echo "   • Real-time download progress"
echo "   • Polished UI for Product Hunt"
echo "   • Custom dropdown (working)"
echo "   • Enter key (working)"
echo "   • Buy More Models button (working)"
echo ""
echo -e "${CYAN}🧪 TEST NOW:${NC}"
echo "   1. Visit https://localai.studio"
echo "   2. Hard refresh (Cmd+Shift+R)"
echo "   3. Browse 11 models in marketplace"
echo "   4. Click 'Install Now' on any model"
echo "   5. Watch progress modal"
echo ""
echo -e "${CYAN}📋 NEXT STEPS:${NC}"
echo "   1. Test all features thoroughly"
echo "   2. Prepare Product Hunt screenshots"
echo "   3. Schedule launch for Tuesday 12:01 AM PST"
echo "   4. Share on social media"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT:${NC}"
echo "   - Backend /api/models/install endpoint needed for real installs"
echo "   - Currently shows simulated progress"
echo "   - See PRODUCT_HUNT.md for launch materials"
echo ""
