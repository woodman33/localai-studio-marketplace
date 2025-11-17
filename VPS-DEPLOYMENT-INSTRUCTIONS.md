# Local AI Studio Marketplace - VPS Deployment Instructions

## Pre-Deployment Checklist

Your VPS is already configured with:
- Docker and Docker Compose installed
- Open WebUI running on port 3000
- Ollama container running on port 11434
- SSH access via Terminus app as root

## Deployment Overview

**Architecture:**
```
Internet (HTTPS 443)
    ↓
Nginx Reverse Proxy
    ↓
├─→ localai.studio → Marketplace Frontend (Port 3001)
├─→ localai.studio/api → Marketplace Backend (Port 8000)
└─→ Shared Ollama (Port 11434)

Existing:
- Open WebUI (Port 3000) - Unchanged
```

**New Services:**
- Marketplace Frontend: Nginx container on port 3001
- Marketplace Backend: FastAPI container on port 8000
- Shared Resource: Existing Ollama container (port 11434)

---

## Step-by-Step Deployment

### Step 1: Connect to VPS via Terminus

1. Open Terminus app on your Mac
2. Connect to "Local AI Studio" server (31.220.109.75)
3. You should be logged in as root

### Step 2: Execute Deployment Script

Copy and paste this command into your Terminus terminal:

```bash
cd /root && \
curl -sSL https://raw.githubusercontent.com/woodman33/localai-studio-marketplace/main/deploy-to-vps.sh -o deploy-to-vps.sh && \
chmod +x deploy-to-vps.sh && \
bash deploy-to-vps.sh
```

**OR** if you prefer to clone the repository first:

```bash
# Clone repository
cd /root
git clone https://github.com/woodman33/localai-studio-marketplace.git
cd localai-studio-marketplace

# Make script executable
chmod +x deploy-to-vps.sh

# Run deployment
bash deploy-to-vps.sh
```

### Step 3: Monitor Deployment

The script will:
1. Clone/update repository
2. Create data directories
3. Generate environment file with `SKIP_PAYMENT=true`
4. Stop old containers (if any)
5. Build and start new containers
6. Configure Nginx reverse proxy
7. Setup SSL certificate (if not exists)
8. Display deployment summary

**Expected Output:**
```
==========================================
Local AI Studio Marketplace Deployment
==========================================

[1/10] Cloning GitHub repository...
✓ Repository ready

[2/10] Creating data directories...
✓ Data directories created

[3/10] Creating environment configuration...
✓ Environment file created

[4/10] Stopping existing marketplace containers...
✓ Old containers stopped

[5/10] Verifying Open WebUI status...
✓ Open WebUI is running on port 3000
✓ Ollama is running on port 11434

[6/10] Building and starting marketplace containers...
✓ Marketplace containers started

[7/10] Waiting for services to be healthy...
✓ Backend is healthy
✓ Frontend is healthy

[8/10] Configuring Nginx reverse proxy...
✓ Nginx configuration is valid
✓ Nginx reloaded

[9/10] Checking SSL certificate...
✓ SSL certificate already exists

[10/10] Deployment summary...

==========================================
DEPLOYMENT SUMMARY
==========================================

✓ DEPLOYMENT COMPLETE
```

### Step 4: Verify Deployment

Run the verification script:

```bash
cd /root/localai-studio-marketplace
chmod +x verify-deployment.sh
bash verify-deployment.sh
```

This will check:
- Docker container status
- Port bindings (3000, 3001, 8000, 11434)
- Backend health endpoint
- Frontend accessibility
- Ollama connectivity
- Nginx configuration
- SSL certificate validity
- Database file creation

### Step 5: Test the Marketplace

1. **Open Browser:** Navigate to `https://localai.studio`
2. **Expected Result:** Marketplace homepage loads with AI chat interface
3. **Test Chat:** Click "Try Free Demo" and send a message
4. **Test Purchase Flow:** Click "Buy Full Access" (SKIP_PAYMENT is enabled, so no real payment)

### Step 6: Verify Open WebUI Still Works

1. **Open Browser:** Navigate to `http://31.220.109.75:3000`
2. **Expected Result:** Open WebUI interface loads normally
3. **Both services should be accessible simultaneously**

---

## Manual Verification Commands

If you want to manually verify everything:

```bash
# Check container status
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Test backend health
curl http://localhost:8000/health

# Test frontend
curl -I http://localhost:3001

# Test Ollama
curl http://localhost:11434/api/tags

# Test HTTPS (from VPS)
curl -I https://localai.studio

# View logs
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml logs -f
```

---

## Post-Deployment Configuration

### Enable Real Payments (Optional)

If you want to enable Stripe payments:

1. Edit environment file:
```bash
nano /root/localai-studio-marketplace/.env
```

2. Update these values:
```env
SKIP_PAYMENT=false
STRIPE_SECRET_KEY=sk_live_YOUR_ACTUAL_KEY
STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_ACTUAL_KEY
STRIPE_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_SECRET
```

3. Restart containers:
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml restart
```

### Add Ollama Models (Optional)

To add more AI models:

```bash
# List current models
docker exec ollama ollama list

# Pull new model
docker exec ollama ollama pull llama3.2:7b

# Test model
docker exec ollama ollama run llama3.2:7b "Hello, test message"
```

### Setup Automatic Backups (Optional)

```bash
# Create backup directory
mkdir -p /root/backups

# Add to crontab
crontab -e

# Add this line (daily backup at 2 AM):
0 2 * * * cp /root/localai-studio-marketplace/data/backend/purchases.db /root/backups/purchases-$(date +\%Y\%m\%d).db
```

---

## Management Commands

### View Logs
```bash
cd /root/localai-studio-marketplace

# All logs
docker compose -f docker-compose.vps.yml logs -f

# Backend only
docker compose -f docker-compose.vps.yml logs -f backend

# Frontend only
docker compose -f docker-compose.vps.yml logs -f frontend

# Last 100 lines
docker compose -f docker-compose.vps.yml logs --tail=100
```

### Restart Services
```bash
cd /root/localai-studio-marketplace

# Restart all
docker compose -f docker-compose.vps.yml restart

# Restart specific service
docker compose -f docker-compose.vps.yml restart backend
docker compose -f docker-compose.vps.yml restart frontend
```

### Stop Services
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml down
```

### Start Services
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml up -d
```

### Update Code
```bash
cd /root/localai-studio-marketplace
git pull
docker compose -f docker-compose.vps.yml down
docker compose -f docker-compose.vps.yml up -d --build
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed troubleshooting guide.

### Quick Fixes

**Container won't start:**
```bash
docker compose -f docker-compose.vps.yml down
docker compose -f docker-compose.vps.yml up -d --force-recreate
```

**502 Bad Gateway:**
```bash
docker compose -f docker-compose.vps.yml restart
nginx -t && systemctl reload nginx
```

**SSL issues:**
```bash
certbot renew --nginx
systemctl reload nginx
```

**Check everything:**
```bash
bash /root/localai-studio-marketplace/verify-deployment.sh
```

---

## Security Considerations

### Firewall Configuration

Ensure only necessary ports are exposed:

```bash
# Check firewall status
ufw status

# Should show:
# 22/tcp    ALLOW   (SSH)
# 80/tcp    ALLOW   (HTTP)
# 443/tcp   ALLOW   (HTTPS)

# Internal ports (3000, 3001, 8000, 11434) should NOT be exposed to internet
# They are accessed via Nginx reverse proxy
```

### SSL Certificate Renewal

Let's Encrypt certificates auto-renew. Verify:

```bash
# Test renewal (dry run)
certbot renew --dry-run

# Force renewal if needed
certbot renew --force-renewal --nginx
```

### Monitor Failed Login Attempts

```bash
# Check SSH login attempts
tail -50 /var/log/auth.log | grep Failed

# Check fail2ban status
fail2ban-client status sshd
```

---

## Performance Monitoring

### Resource Usage
```bash
# Real-time stats
docker stats

# Disk usage
df -h
du -sh /root/localai-studio-marketplace/data

# Memory usage
free -h
```

### Log Monitoring
```bash
# Nginx access logs
tail -f /var/log/nginx/localai.studio.access.log

# Nginx error logs
tail -f /var/log/nginx/localai.studio.error.log

# Application logs
docker compose -f docker-compose.vps.yml logs -f
```

---

## Rollback Plan

If deployment fails and you need to rollback:

```bash
# Stop marketplace containers
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml down

# Restore old Nginx config (if backed up)
cp /etc/nginx/sites-available/localai.studio.backup.YYYYMMDDHHMMSS \
   /etc/nginx/sites-available/localai.studio
nginx -t && systemctl reload nginx

# Open WebUI should still be running on port 3000
docker ps | grep open-webui
```

---

## Support

If you encounter issues:

1. Run verification script: `bash verify-deployment.sh`
2. Check logs: `docker compose logs --tail=100`
3. Review troubleshooting guide: `TROUBLESHOOTING.md`
4. Collect diagnostic info (see troubleshooting guide)

---

## File Locations

**Configuration Files:**
- Docker Compose: `/root/localai-studio-marketplace/docker-compose.vps.yml`
- Environment: `/root/localai-studio-marketplace/.env`
- Nginx Config: `/etc/nginx/sites-available/localai.studio`

**Data Files:**
- Database: `/root/localai-studio-marketplace/data/backend/purchases.db`
- Backend Data: `/root/localai-studio-marketplace/data/backend/`

**Log Files:**
- Nginx Access: `/var/log/nginx/localai.studio.access.log`
- Nginx Error: `/var/log/nginx/localai.studio.error.log`
- Docker Logs: `docker compose logs`

**Scripts:**
- Deployment: `/root/localai-studio-marketplace/deploy-to-vps.sh`
- Verification: `/root/localai-studio-marketplace/verify-deployment.sh`

---

## Next Steps

After successful deployment:

1. Test the marketplace at https://localai.studio
2. Verify Open WebUI still works at http://31.220.109.75:3000
3. Monitor logs for any errors
4. Setup automatic backups (optional)
5. Configure Stripe for real payments (when ready)
6. Add more Ollama models (optional)

---

## Success Criteria

Deployment is successful when:
- ✓ https://localai.studio loads the marketplace
- ✓ AI chat functionality works (test with free demo)
- ✓ Purchase flow works (even with SKIP_PAYMENT=true)
- ✓ Open WebUI still accessible at http://31.220.109.75:3000
- ✓ All containers running: `docker ps` shows 4 containers
- ✓ No errors in logs
- ✓ SSL certificate valid
- ✓ Nginx serving both domains correctly

---

**Deployment Time:** ~10-15 minutes
**Difficulty:** Easy (fully automated)
**Risk Level:** Low (Open WebUI unaffected)
