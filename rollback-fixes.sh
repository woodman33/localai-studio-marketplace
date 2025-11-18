#!/bin/bash
# Local AI Studio Marketplace - Rollback Script
# Run this on VPS if fixes cause issues: bash rollback-fixes.sh

set -e

echo "=========================================="
echo "Local AI Studio - Rollback Fixes"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="/root/localai-studio-marketplace"
cd "$PROJECT_DIR"

echo -e "${YELLOW}Finding most recent backups...${NC}"

# Find most recent HTML backup
HTML_BACKUP=$(ls -t local-ai-studio-with-affiliates.html.backup-* 2>/dev/null | head -1)
if [ -n "$HTML_BACKUP" ]; then
    echo "Found HTML backup: $HTML_BACKUP"
    cp "$HTML_BACKUP" local-ai-studio-with-affiliates.html
    echo -e "${GREEN}✓ Restored HTML file${NC}"
else
    echo -e "${YELLOW}⚠ No HTML backup found${NC}"
fi

# Find most recent nginx backup
NGINX_BACKUP=$(ls -t /etc/nginx/sites-available/localai.studio.backup-* 2>/dev/null | head -1)
if [ -n "$NGINX_BACKUP" ]; then
    echo "Found nginx backup: $NGINX_BACKUP"
    cp "$NGINX_BACKUP" /etc/nginx/sites-available/localai.studio

    # Test nginx config
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx
        echo -e "${GREEN}✓ Restored nginx configuration${NC}"
    else
        echo -e "${RED}✗ Nginx configuration test failed after restore${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ No nginx backup found${NC}"
fi

echo ""
echo -e "${YELLOW}Restarting frontend container...${NC}"
docker compose -f docker-compose.production.yml restart frontend
echo -e "${GREEN}✓ Frontend restarted${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}ROLLBACK COMPLETED${NC}"
echo "=========================================="
echo ""
echo "Your configuration has been restored to the previous state."
echo "Test the site: https://localai.studio"
echo ""
