#!/bin/bash
# EMERGENCY DEPLOYMENT - Dropdown & Button Fixes
# Run on VPS: bash DEPLOY_NOW.sh

set -e

echo "=========================================="
echo "EMERGENCY FIX DEPLOYMENT"
echo "=========================================="
echo ""

cd /root/localai-studio-marketplace

echo "Step 1: Pull latest fixes from GitHub..."
git fetch origin
git reset --hard origin/main
echo "✓ Latest code pulled"
echo ""

echo "Step 2: Verify fixes are present..."
if grep -q "webkit-appearance: none" local-ai-studio-with-affiliates.html; then
    echo "✓ Dropdown CSS fix found"
else
    echo "✗ ERROR: Dropdown fix missing!"
    exit 1
fi

if grep -q "messagesContainer.innerHTML = '';" local-ai-studio-with-affiliates.html; then
    echo "✓ Scroll function fix found"
else
    echo "✗ ERROR: Scroll fix missing!"
    exit 1
fi
echo ""

echo "Step 3: Recreate frontend container..."
docker compose -f docker-compose.production.yml stop frontend
docker compose -f docker-compose.production.yml rm -f frontend
docker compose -f docker-compose.production.yml up -d frontend
echo "✓ Container recreated"
echo ""

echo "Step 4: Wait for container startup..."
sleep 5
echo "✓ Ready"
echo ""

echo "Step 5: Verify new file is mounted..."
if docker exec localai-frontend grep -q "webkit-appearance: none" /usr/share/nginx/html/marketplace.html; then
    echo "✓ New file is loaded in container"
else
    echo "✗ WARNING: Container may have old file"
fi
echo ""

echo "=========================================="
echo "DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🧪 TEST NOW:"
echo "1. Visit: https://localai.studio"
echo "2. Hard refresh: Cmd+Shift+R"
echo "3. Click model dropdown - text should be WHITE"
echo "4. Click 'Buy More Models' - should show marketplace"
echo ""
