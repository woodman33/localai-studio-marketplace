# Local AI Studio Marketplace - Troubleshooting Guide

## Quick Diagnostics

### Check All Services Status
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml ps
```

### View Real-Time Logs
```bash
# All services
docker compose -f docker-compose.vps.yml logs -f

# Backend only
docker compose -f docker-compose.vps.yml logs -f backend

# Frontend only
docker compose -f docker-compose.vps.yml logs -f frontend
```

### Test Endpoints
```bash
# Backend health check
curl http://localhost:8000/health

# Frontend accessibility
curl -I http://localhost:3001

# Ollama connectivity
curl http://localhost:11434/api/tags

# HTTPS access (from outside)
curl -I https://localai.studio
```

---

## Common Issues

### 1. Backend Container Fails to Start

**Symptoms:**
- `localai-marketplace-backend` container exits immediately
- Error: "Connection refused" to Ollama

**Solution:**
```bash
# Check if Ollama is running
docker ps | grep ollama

# If Ollama is not running, start Open WebUI stack first
cd /root/local-ai-studio
docker compose up -d

# Then restart marketplace
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml restart backend
```

**Root Cause:** Backend needs Ollama to be running on port 11434.

---

### 2. Port Conflict (Port Already in Use)

**Symptoms:**
- Error: "bind: address already in use"
- Cannot start containers

**Solution:**
```bash
# Check what's using the ports
netstat -tuln | grep -E "3001|8000"

# If marketplace containers are stuck
docker rm -f localai-marketplace-backend localai-marketplace-frontend

# Restart
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml up -d
```

---

### 3. Nginx 502 Bad Gateway

**Symptoms:**
- `https://localai.studio` shows "502 Bad Gateway"
- Nginx logs show "connect() failed"

**Solution:**
```bash
# Check if backend/frontend are running
docker ps | grep marketplace

# Test local access
curl http://localhost:3001
curl http://localhost:8000/health

# Check Nginx error logs
tail -50 /var/log/nginx/localai.studio.error.log

# Restart containers
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml restart

# Reload Nginx
nginx -t && systemctl reload nginx
```

---

### 4. SSL Certificate Issues

**Symptoms:**
- Browser shows "Your connection is not private"
- Certificate expired or not valid

**Solution:**
```bash
# Check certificate expiry
openssl x509 -enddate -noout -in /etc/letsencrypt/live/localai.studio/fullchain.pem

# Renew certificate
certbot renew --nginx

# Force renewal (if needed)
certbot renew --force-renewal --nginx

# Test certificate renewal (dry run)
certbot renew --dry-run
```

---

### 5. Database Permission Issues

**Symptoms:**
- Backend logs show "Permission denied: purchases.db"
- Cannot create database file

**Solution:**
```bash
# Fix directory permissions
mkdir -p /root/localai-studio-marketplace/data/backend
chmod -R 755 /root/localai-studio-marketplace/data
chown -R root:root /root/localai-studio-marketplace/data

# Restart backend
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml restart backend
```

---

### 6. Cannot Connect to Ollama from Backend

**Symptoms:**
- Backend logs: "Connection refused to host.docker.internal:11434"
- AI features not working

**Solution:**
```bash
# Verify Ollama is accessible from host
curl http://localhost:11434/api/tags

# Check Docker network configuration
docker compose -f docker-compose.vps.yml down
docker compose -f docker-compose.vps.yml up -d

# Alternative: Use Docker network instead of host.docker.internal
# Edit docker-compose.vps.yml and change OLLAMA_BASE_URL to:
# OLLAMA_BASE_URL=http://ollama:11434
# Then connect marketplace to the same network as Ollama
```

---

### 7. Open WebUI Conflicts with Marketplace

**Symptoms:**
- Open WebUI stops working after marketplace deployment
- Port 3000 not accessible

**Solution:**
```bash
# Verify Open WebUI is running
docker ps | grep open-webui

# Restart Open WebUI if needed
cd /root/local-ai-studio
docker compose restart

# Both should be running on different ports:
# - Open WebUI: 3000
# - Marketplace: 3001
```

---

## Complete Reset (Nuclear Option)

If everything is broken and you need to start fresh:

```bash
# Stop and remove all marketplace containers
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml down -v

# Remove containers
docker rm -f localai-marketplace-backend localai-marketplace-frontend

# Remove images (optional)
docker rmi localai-marketplace-backend:latest

# Backup data if needed
cp -r /root/localai-studio-marketplace/data /root/marketplace-data-backup

# Pull latest code
git pull

# Redeploy
bash deploy-to-vps.sh
```

---

## Monitoring and Maintenance

### View Resource Usage
```bash
# Docker stats
docker stats

# Disk usage
df -h
du -sh /root/localai-studio-marketplace/data

# Memory usage
free -h
```

### Clean Up Docker
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune
```

### Backup Database
```bash
# Create backup
cp /root/localai-studio-marketplace/data/backend/purchases.db \
   /root/marketplace-backup-$(date +%Y%m%d).db

# Automated backup script (add to cron)
0 2 * * * cp /root/localai-studio-marketplace/data/backend/purchases.db /root/backups/purchases-$(date +\%Y\%m\%d).db
```

---

## Security Checks

### Verify Firewall
```bash
ufw status
# Should allow: 22 (SSH), 80 (HTTP), 443 (HTTPS)
# Should block: 3000, 3001, 8000, 11434 (internal only)
```

### Check Failed Login Attempts
```bash
# View fail2ban status
fail2ban-client status sshd

# View SSH logs
tail -50 /var/log/auth.log | grep Failed
```

### Update System
```bash
apt update
apt upgrade -y
apt autoremove -y
```

---

## Getting Help

### Collect Diagnostic Information
```bash
# System info
uname -a
docker --version
docker compose version
nginx -v

# Container status
docker ps -a

# All logs
docker compose -f docker-compose.vps.yml logs --tail=100

# Nginx logs
tail -50 /var/log/nginx/localai.studio.error.log

# System resources
free -h
df -h
docker stats --no-stream
```

### Support Checklist
Before requesting help, collect:
1. Output of `docker ps -a`
2. Backend logs: `docker compose logs backend --tail=100`
3. Frontend logs: `docker compose logs frontend --tail=100`
4. Nginx error log: `tail -50 /var/log/nginx/localai.studio.error.log`
5. Screenshot of browser error (if applicable)
6. Output of `curl http://localhost:8000/health`

---

## Performance Optimization

### Reduce Memory Usage
Edit `/root/localai-studio-marketplace/docker-compose.vps.yml`:
```yaml
deploy:
  resources:
    limits:
      memory: 1G  # Reduce from 2G
```

### Enable Log Rotation
Already configured in docker-compose.vps.yml:
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### Clean Old Logs
```bash
# Docker logs
docker system prune -a --volumes

# Nginx logs
find /var/log/nginx -name "*.log" -mtime +30 -delete
```
