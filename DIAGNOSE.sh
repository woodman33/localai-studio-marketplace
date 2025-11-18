#!/bin/bash
# DIAGNOSTIC - Why aren't the fixes showing?

echo "=========================================="
echo "DIAGNOSING DEPLOYMENT ISSUE"
echo "=========================================="
echo ""

cd /root/localai-studio-marketplace

echo "1. Check if fixes are in the HOST file:"
echo "-------------------------------------------"
grep -c "webkit-appearance: none" local-ai-studio-with-affiliates.html
echo "^ Should be 3 (CSS fix count)"
grep -c "messagesContainer.innerHTML = '';" local-ai-studio-with-affiliates.html
echo "^ Should be 1 (JS fix count)"
echo ""

echo "2. Check if fixes are in the CONTAINER file:"
echo "-------------------------------------------"
docker exec localai-frontend grep -c "webkit-appearance: none" /usr/share/nginx/html/marketplace.html
echo "^ Should be 3 (CSS fix count)"
docker exec localai-frontend grep -c "messagesContainer.innerHTML = '';" /usr/share/nginx/html/marketplace.html
echo "^ Should be 1 (JS fix count)"
echo ""

echo "3. Check what nginx ACTUALLY serves via HTTP:"
echo "-------------------------------------------"
curl -s http://localhost:3000/ | grep -o "webkit-appearance: none" | wc -l
echo "^ Should be 3 (in HTTP response)"
curl -s http://localhost:3000/ | grep -o "messagesContainer.innerHTML = '';" | wc -l
echo "^ Should be 1 (in HTTP response)"
echo ""

echo "4. Check if host nginx is caching:"
echo "-------------------------------------------"
grep -i "cache" /etc/nginx/sites-available/localai.studio || echo "No cache directives found"
echo ""

echo "5. Test from public URL:"
echo "-------------------------------------------"
curl -s https://localai.studio | grep -c "webkit-appearance: none"
echo "^ Should be 3 (from public URL)"
echo ""

echo "6. Check HTTP headers for caching:"
echo "-------------------------------------------"
curl -I https://localai.studio | grep -i cache
echo ""

echo "=========================================="
echo "If all counts are correct but browser still"
echo "shows old version, this is BROWSER CACHE."
echo "=========================================="
echo ""
echo "FIX: Open browser incognito/private window"
echo "Test: https://localai.studio"
echo ""
