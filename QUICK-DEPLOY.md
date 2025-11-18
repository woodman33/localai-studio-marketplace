# Local AI Studio - Quick Deploy Reference Card

## PRE-FLIGHT CRITICAL FIX

**MUST DO BEFORE DEPLOYING:**

Edit `/Users/willmeldman/localai-studio-marketplace/backend-chat.py`:

```python
# Line 1-15 area: ADD this after imports
DB_PATH = os.path.join('/app/data', 'purchases.db')

# Line 50-65 area: UPDATE init_db()
def init_db():
    """Create purchases database if it doesn't exist"""
    os.makedirs('/app/data', exist_ok=True)  # ADD THIS
    conn = sqlite3.connect(DB_PATH)          # CHANGE THIS
    # ... rest unchanged

# Lines 243, 253, 271: REPLACE ALL
sqlite3.connect('purchases.db')  # OLD
sqlite3.connect(DB_PATH)         # NEW
```

**Search & Replace:** Change all 4 instances of `sqlite3.connect('purchases.db')` to `sqlite3.connect(DB_PATH)`

---

## ONE-COMMAND DEPLOY

```bash
# Mac: Transfer files
scp -r /Users/willmeldman/localai-studio-marketplace/* root@31.220.109.75:/root/localai-studio-marketplace/

# VPS: Deploy everything
ssh root@31.220.109.75 "cd /root/localai-studio-marketplace && ./deploy-vps.sh && cp nginx-host.conf /etc/nginx/sites-available/localai.studio && ln -sf /etc/nginx/sites-available/localai.studio /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx && certbot --nginx -d localai.studio -d www.localai.studio --non-interactive --agree-tos -m admin@localai.studio"
```

---

## 3-STEP MANUAL DEPLOY

### Step 1: Transfer & Deploy (VPS)
```bash
# Transfer files (from Mac)
cd /Users/willmeldman/localai-studio-marketplace
scp -r * root@31.220.109.75:/root/localai-studio-marketplace/

# SSH to VPS (Terminus app)
ssh root@31.220.109.75
cd /root/localai-studio-marketplace
./deploy-vps.sh
```

### Step 2: Configure Nginx (VPS)
```bash
cp nginx-host.conf /etc/nginx/sites-available/localai.studio
ln -s /etc/nginx/sites-available/localai.studio /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### Step 3: Setup SSL (VPS)
```bash
certbot --nginx -d localai.studio -d www.localai.studio
```

---

## VERIFY DEPLOYMENT

```bash
# On VPS
./health-check.sh

# Or manually
curl http://localhost:8000/health  # Backend
curl http://localhost:3000          # Frontend
docker exec localai-ollama ollama list  # Models

# From anywhere
curl https://localai.studio
curl https://localai.studio/marketplace
```

---

## DAILY OPERATIONS

```bash
# Status
./health-check.sh

# Logs
docker compose -f docker-compose.production.yml logs -f

# Restart
docker compose -f docker-compose.production.yml restart

# Add model
docker exec localai-ollama ollama pull llama3.2:3b

# Database
sqlite3 /root/localai-studio-marketplace/data/backend/purchases.db "SELECT * FROM purchases;"
```

---

## TROUBLESHOOTING

```bash
# Rebuild everything
docker compose -f docker-compose.production.yml down -v
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d

# Check database path
docker exec localai-backend ls -la /app/data/

# Test Ollama connectivity
docker exec localai-backend curl http://ollama:11434/api/tags
```

---

## FILES CREATED

Production deployment files:
- `docker-compose.production.yml` - Production Docker config (3.4K)
- `Dockerfile.backend.optimized` - Optimized backend image (1.4K)
- `.dockerignore` - Build exclusions (616B)
- `nginx-host.conf` - Host Nginx config (4.3K)
- `deploy-vps.sh` - Automated deployment (5.4K)
- `health-check.sh` - Health monitoring (3.8K)
- `backup-and-monitor.sh` - Automated backups (3.4K)

Documentation:
- `VPS-DEPLOYMENT-GUIDE.md` - Complete guide (13K)
- `DEPLOYMENT-SUMMARY.md` - Executive summary (12K)
- `QUICK-DEPLOY.md` - This file (2K)

---

## KEY IMPROVEMENTS

Your original `docker-compose.yml` (57 lines) upgraded to:
- `docker-compose.production.yml` (138 lines)

Your original `Dockerfile.backend` (19 lines) upgraded to:
- `Dockerfile.backend.optimized` (57 lines)

**Added:**
- Health checks (all 3 services)
- Resource limits (prevents RAM exhaustion)
- Bind mounts (data persistence)
- Security hardening (non-root user, localhost-only ports)
- Log rotation (prevents disk fill)
- Multi-stage build (smaller images)
- Production optimizations

---

## CRITICAL: DATABASE FIX

Without fixing the database path in `backend-chat.py`:
- Purchases saved to `/purchases.db` (ephemeral)
- Container restart = all purchases lost
- Production = disaster

With fix:
- Purchases saved to `/app/data/purchases.db` (mounted volume)
- Container restart = purchases preserved
- Production = safe

**Status Check:**
```bash
# After deployment, verify database location
docker exec localai-backend ls -la /app/data/purchases.db
# Should exist and be writable

# Make a test purchase, then restart
docker restart localai-backend
sqlite3 /root/localai-studio-marketplace/data/backend/purchases.db "SELECT * FROM purchases;"
# Purchase should still be there
```

---

## BACKUP SETUP

```bash
# Add to crontab (runs daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /root/localai-studio-marketplace/backup-and-monitor.sh

# Verify
crontab -l
```

Backups saved to: `/root/backups/localai/localai_backup_YYYYMMDD_HHMMSS.tar.gz`

---

## RESOURCES (16GB VPS)

Configured limits:
- Ollama: 8GB RAM, 4 CPUs
- Backend: 2GB RAM, 2 CPUs
- Frontend: 256MB RAM, 0.5 CPUs
- System: ~6GB reserved

Adjust in `docker-compose.production.yml` if needed.

---

## NEXT STEPS

After successful deployment:
1. Test marketplace purchase flow (SKIP_PAYMENT=true)
2. Verify database persistence across restarts
3. Monitor logs for 24 hours
4. Configure Stripe webhook (when ready for real payments)
5. Setup firewall rules: `ufw allow 22,80,443/tcp && ufw enable`
6. Add uptime monitoring (UptimeRobot)

---

**VPS:** 31.220.109.75 (Hostinger)
**Domain:** localai.studio
**SSH:** Via Terminus app
**Total Deploy Time:** ~5 minutes
