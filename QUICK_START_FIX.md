# Local AI Studio Marketplace - Quick Fix Guide

## Issues to Fix
1. **500 error on first load** - White page, works on reload
2. **Background color bug** - White background → blue after interaction
3. **Buy More Models button** - Doesn't scroll to marketplace

## Root Causes Identified

### Issue 1: 500 Error (Backend Startup Race)
- Nginx proxies to backend before containers are fully ready
- Missing retry logic and upstream health checks
- Backend healthcheck may have wrong endpoint path

### Issue 2: Background Color (CSS Loading)
- Caused by Issue 1 - 500 error prevents CSS from loading
- No caching headers for static assets

### Issue 3: Scroll Button
- JavaScript targets wrong element
- `.models-grid` is inside `.messages` scrollable container
- `scrollIntoView()` doesn't work for nested scroll containers

## Quick Fix (Run on VPS via Terminus)

### Option 1: Automated Fix Script (Recommended)

```bash
# SSH into VPS via Terminus app
cd /root/localai-studio-marketplace

# Download and run fix script
bash fix-all-issues.sh

# Wait for completion (about 60 seconds)
# Then test site: https://localai.studio
```

### Option 2: Manual Fixes

#### Fix 1: Update Nginx Config

```bash
# Backup current config
cp /etc/nginx/sites-available/localai.studio /etc/nginx/sites-available/localai.studio.backup

# Create new config with upstream retry logic
# See VPS_DIAGNOSTIC_AND_FIX.md for full config

# Test and reload
nginx -t && systemctl reload nginx
```

#### Fix 2: Fix JavaScript Scroll Function

```bash
cd /root/localai-studio-marketplace

# Backup HTML
cp local-ai-studio-with-affiliates.html local-ai-studio-with-affiliates.html.backup

# Run Python fix script (see fix-all-issues.sh)
# Replaces scrollToMarketplace() function

# Restart frontend
docker compose -f docker-compose.production.yml restart frontend
```

#### Fix 3: Verify Backend Health

```bash
# Check health endpoint
docker exec localai-backend curl -f http://localhost:8000/health

# If fails, try:
docker exec localai-backend curl -f http://localhost:8000/api/health

# Update docker-compose.yml healthcheck to match working endpoint
```

## Verification Steps

### 1. Clear Browser Cache
- Mac: Cmd + Shift + R
- Windows/Linux: Ctrl + Shift + R
- Or use Incognito/Private window

### 2. Test All Issues Fixed
1. Visit https://localai.studio
   - ✓ Should load immediately without 500 error
   - ✓ Blue gradient background visible immediately
2. Click "💎 Buy More Models" button
   - ✓ Should smoothly scroll to marketplace model cards

### 3. Check Logs (if issues persist)
```bash
# Container logs
docker compose -f docker-compose.production.yml logs -f

# Nginx errors
tail -f /var/log/nginx/localai.studio.error.log

# Container health status
docker compose -f docker-compose.production.yml ps
```

## Rollback (if needed)

```bash
cd /root/localai-studio-marketplace
bash rollback-fixes.sh
```

## Files Created

1. **VPS_DIAGNOSTIC_AND_FIX.md** - Comprehensive diagnostic guide (15+ pages)
2. **fix-all-issues.sh** - Automated fix script
3. **rollback-fixes.sh** - Rollback script
4. **QUICK_START_FIX.md** - This file

## Expected Results After Fix

### Before Fix:
- First load: 500 error white screen
- Reload: Works, but white background
- After clicking: Background turns blue
- Scroll button: Does nothing

### After Fix:
- First load: ✓ Loads immediately with blue background
- Every load: ✓ Blue gradient visible instantly
- Scroll button: ✓ Smoothly scrolls to marketplace
- No errors: ✓ Browser console clean

## Technical Details

### Nginx Improvements
- Upstream health checks with retry logic
- 3 retry attempts with 10s timeout
- Proper error handling (503 service unavailable page)
- Connection keepalive for better performance
- Cache headers for static assets

### JavaScript Fix
- Changed from `scrollIntoView()` to `scrollTo()`
- Calculates position within scrollable container
- Smooth scroll with 20px padding offset
- Fallback to top of models section

### Docker Improvements
- Healthcheck with 40s start_period
- Proper depends_on with health conditions
- Memory and CPU limits configured

## VPS Details

**Access:**
- IP: 31.220.109.75
- URL: https://localai.studio
- SSH: Terminus app → "Local AI Studio" server

**Key Directories:**
- Project: `/root/localai-studio-marketplace/`
- Nginx: `/etc/nginx/sites-available/localai.studio`
- Logs: `/var/log/nginx/`

**Key Commands:**
```bash
# Status check
cd /root/localai-studio-marketplace
docker compose -f docker-compose.production.yml ps

# View logs
docker compose -f docker-compose.production.yml logs -f

# Restart services
docker compose -f docker-compose.production.yml restart

# Full restart
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d
```

## Support

If issues persist after running fixes:

1. Check container health: `docker compose -f docker-compose.production.yml ps`
2. Check backend logs: `docker logs localai-backend --tail 50`
3. Check nginx logs: `tail -50 /var/log/nginx/localai.studio.error.log`
4. Test backend directly: `curl http://127.0.0.1:8000/health`
5. Test frontend directly: `curl http://127.0.0.1:3000`

## Next Steps After Fix

1. Monitor site for 24 hours to ensure stability
2. Set up monitoring/alerting (see VPS_DIAGNOSTIC_AND_FIX.md)
3. Consider adding rate limiting
4. Enable gzip compression for better performance
5. Set up automated backups

---

**Last Updated:** 2025-11-17
**Files Location:** `/Users/willmeldman/localai-studio-marketplace/`
