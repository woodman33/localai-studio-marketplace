# Local AI Studio Marketplace - VPS Deployment Guide

## System Information
- **VPS Provider:** Hostinger
- **IP Address:** 31.220.109.75
- **OS:** Ubuntu 24.04 LTS
- **RAM:** 16GB
- **Domain:** localai.studio
- **SSH Access:** Via Terminus app → "Local AI Studio" server

---

## Pre-Deployment Checklist

### 1. Local Mac Preparation
```bash
# Navigate to project
cd /Users/willmeldman/localai-studio-marketplace

# Fix critical database path bug
# Edit backend-chat.py and replace all instances of:
# sqlite3.connect('purchases.db')
# WITH:
# sqlite3.connect(DB_PATH)
# AND add at top: DB_PATH = os.path.join('/app/data', 'purchases.db')

# Make scripts executable
chmod +x deploy-vps.sh health-check.sh backup-and-monitor.sh

# Transfer files to VPS
scp -r * root@31.220.109.75:/root/localai-studio-marketplace/
```

### 2. VPS Prerequisites
```bash
# SSH into VPS via Terminus app
ssh root@31.220.109.75

# Update system
apt update && apt upgrade -y

# Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose V2
apt install -y docker-compose-plugin

# Install utilities
apt install -y curl wget git sqlite3 nginx certbot python3-certbot-nginx

# Verify Docker
docker --version
docker compose version
```

---

## Deployment Steps

### Step 1: Transfer Files to VPS
```bash
# From your Mac
cd /Users/willmeldman/localai-studio-marketplace
scp -r * root@31.220.109.75:/root/localai-studio-marketplace/

# OR clone from git (if repository set up)
# ssh root@31.220.109.75
# git clone <your-repo> /root/localai-studio-marketplace
```

### Step 2: Run Deployment Script
```bash
# SSH into VPS
ssh root@31.220.109.75

# Navigate to project
cd /root/localai-studio-marketplace

# Make script executable
chmod +x deploy-vps.sh

# Run deployment
./deploy-vps.sh
```

**What the script does:**
1. Creates project and data directories
2. Sets up bind mounts for volumes
3. Creates production .env file
4. Builds Docker images with optimizations
5. Starts all services with health checks
6. Pulls TinyLlama model
7. Verifies deployment

### Step 3: Configure Host Nginx
```bash
# Copy nginx configuration
cp /root/localai-studio-marketplace/nginx-host.conf \
   /etc/nginx/sites-available/localai.studio

# Create symbolic link
ln -s /etc/nginx/sites-available/localai.studio \
      /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# If OK, reload nginx
systemctl reload nginx
```

### Step 4: Setup SSL Certificate
```bash
# Get Let's Encrypt certificate
certbot --nginx -d localai.studio -d www.localai.studio

# Test auto-renewal
certbot renew --dry-run

# Auto-renewal is configured via systemd timer
systemctl status certbot.timer
```

---

## Health Checks & Verification

### Automated Health Check
```bash
cd /root/localai-studio-marketplace
./health-check.sh
```

### Manual Verification Commands
```bash
# Check container status
docker compose -f docker-compose.production.yml ps

# Check container health
docker ps --format "{{.Names}}: {{.Status}}"

# Test backend API
curl http://localhost:8000/health
# Expected: {"status":"healthy","service":"Local AI Studio Backend"}

# Test frontend
curl -I http://localhost:3000
# Expected: HTTP/1.1 200 OK

# Check Ollama models
docker exec localai-ollama ollama list

# Test Ollama connectivity from backend
docker exec localai-backend curl http://ollama:11434/api/tags

# Check database
sqlite3 /root/localai-studio-marketplace/data/backend/purchases.db "SELECT COUNT(*) FROM purchases;"

# View logs
docker compose -f docker-compose.production.yml logs -f

# View specific service logs
docker compose -f docker-compose.production.yml logs -f backend
docker compose -f docker-compose.production.yml logs -f ollama
docker compose -f docker-compose.production.yml logs -f frontend
```

### External Access Tests
```bash
# From your Mac or any external machine
curl https://localai.studio
curl https://localai.studio/marketplace
curl https://localai.studio/api/models
```

---

## Container Management

### Start/Stop Services
```bash
cd /root/localai-studio-marketplace

# Start all services
docker compose -f docker-compose.production.yml up -d

# Stop all services
docker compose -f docker-compose.production.yml down

# Restart specific service
docker compose -f docker-compose.production.yml restart backend

# Rebuild and restart
docker compose -f docker-compose.production.yml up -d --build

# View resource usage
docker stats
```

### Model Management
```bash
# List installed models
docker exec localai-ollama ollama list

# Pull new model
docker exec localai-ollama ollama pull llama3.2:3b

# Remove model
docker exec localai-ollama ollama rm <model-name>

# Test model
docker exec localai-ollama ollama run tinyllama:latest "Hello, how are you?"
```

### Database Operations
```bash
# Path to database
DB_PATH="/root/localai-studio-marketplace/data/backend/purchases.db"

# View all purchases
sqlite3 $DB_PATH "SELECT * FROM purchases;"

# Count purchases
sqlite3 $DB_PATH "SELECT COUNT(*) FROM purchases;"

# Check integrity
sqlite3 $DB_PATH "PRAGMA integrity_check;"

# Backup database manually
cp $DB_PATH $DB_PATH.backup.$(date +%Y%m%d_%H%M%S)
```

---

## Monitoring & Maintenance

### Setup Automated Monitoring
```bash
# Make backup script executable
chmod +x /root/localai-studio-marketplace/backup-and-monitor.sh

# Add to crontab (runs daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /root/localai-studio-marketplace/backup-and-monitor.sh

# Verify crontab
crontab -l
```

### Manual Backup
```bash
cd /root/localai-studio-marketplace

# Create backup
tar -czf backup_$(date +%Y%m%d_%H%M%S).tar.gz \
    data/ .env docker-compose.production.yml

# List backups
ls -lh backup_*.tar.gz
```

### Resource Monitoring
```bash
# Real-time stats
docker stats

# Disk usage
df -h
du -sh /root/localai-studio-marketplace/data/*

# Memory usage
free -h

# Check Docker disk usage
docker system df

# Clean up unused resources
docker system prune -af --volumes
```

### Log Management
```bash
# View all logs
docker compose -f docker-compose.production.yml logs -f

# View logs for last hour
docker compose -f docker-compose.production.yml logs --since 1h

# View last 100 lines
docker compose -f docker-compose.production.yml logs --tail=100

# Search for errors
docker compose -f docker-compose.production.yml logs | grep -i error

# Check Nginx access logs
tail -f /var/log/nginx/localai.studio.access.log

# Check Nginx error logs
tail -f /var/log/nginx/localai.studio.error.log
```

---

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker compose -f docker-compose.production.yml logs <service-name>

# Check container status
docker inspect <container-name>

# Force recreate
docker compose -f docker-compose.production.yml up -d --force-recreate

# Rebuild from scratch
docker compose -f docker-compose.production.yml down -v
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d
```

### Database Issues
```bash
# Check if database exists
ls -lh /root/localai-studio-marketplace/data/backend/

# Check permissions
ls -la /root/localai-studio-marketplace/data/backend/

# Fix permissions
chmod 755 /root/localai-studio-marketplace/data/backend
chown -R 1000:1000 /root/localai-studio-marketplace/data/backend

# Recreate database
docker exec localai-backend python3 -c "from backend-chat import init_db; init_db()"
```

### Ollama Connection Issues
```bash
# Check if Ollama is running
docker ps | grep ollama

# Restart Ollama
docker restart localai-ollama

# Check Ollama logs
docker logs localai-ollama

# Test connectivity
docker exec localai-backend curl http://ollama:11434/api/tags
```

### Network Issues
```bash
# Check network
docker network ls | grep localai

# Inspect network
docker network inspect localai-network

# Recreate network
docker compose -f docker-compose.production.yml down
docker network rm localai-network
docker compose -f docker-compose.production.yml up -d
```

### SSL Certificate Issues
```bash
# Check certificate status
certbot certificates

# Renew certificate
certbot renew

# Force renewal
certbot renew --force-renewal

# Check Nginx SSL config
nginx -t
```

---

## Performance Optimization

### Resource Limits
The production compose file includes:
- **Ollama:** 8GB RAM limit, 4 CPU cores
- **Backend:** 2GB RAM limit, 2 CPU cores
- **Frontend:** 256MB RAM limit, 0.5 CPU cores

Adjust in `docker-compose.production.yml` based on your models:
```yaml
deploy:
  resources:
    limits:
      memory: 8G
      cpus: '4.0'
```

### Model Optimization
```bash
# Use quantized models for lower RAM
# Instead of: llama3.2:3b (full precision)
# Use: llama3.2:3b-q4_0 (4-bit quantization)

docker exec localai-ollama ollama pull llama3.2:3b-q4_0
```

### Log Rotation
```bash
# Configure Docker log rotation in /etc/docker/daemon.json
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker
systemctl restart docker
```

---

## Security Best Practices

### Firewall Configuration
```bash
# Allow SSH, HTTP, HTTPS
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Deny direct access to container ports
ufw deny 3000/tcp
ufw deny 8000/tcp
ufw deny 11434/tcp

# Enable firewall
ufw --force enable
ufw status
```

### Stripe Webhook Security
When configuring Stripe webhook in production:
1. Go to Stripe Dashboard → Webhooks
2. Add endpoint: `https://localai.studio/api/stripe/webhook`
3. Select events: `checkout.session.completed`
4. Copy webhook secret to `.env`: `STRIPE_WEBHOOK_SECRET=whsec_xxx`
5. Set `SKIP_PAYMENT=false` in `.env`
6. Restart backend: `docker compose -f docker-compose.production.yml restart backend`

---

## Update Procedures

### Update Application Code
```bash
# SSH to VPS
ssh root@31.220.109.75
cd /root/localai-studio-marketplace

# Pull latest changes (if using git)
git pull

# OR transfer files from Mac
# scp -r /Users/willmeldman/localai-studio-marketplace/* root@31.220.109.75:/root/localai-studio-marketplace/

# Rebuild and restart
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d

# Check logs
docker compose -f docker-compose.production.yml logs -f
```

### Update Docker Images
```bash
# Pull latest base images
docker compose -f docker-compose.production.yml pull

# Rebuild with new base
docker compose -f docker-compose.production.yml build --pull

# Restart services
docker compose -f docker-compose.production.yml up -d
```

---

## Important File Locations

### Configuration Files
```
/root/localai-studio-marketplace/.env                      # Environment variables
/root/localai-studio-marketplace/docker-compose.production.yml  # Docker config
/etc/nginx/sites-available/localai.studio                  # Nginx config
/etc/letsencrypt/live/localai.studio/                      # SSL certificates
```

### Data Volumes
```
/root/localai-studio-marketplace/data/ollama/              # Ollama models
/root/localai-studio-marketplace/data/backend/purchases.db # Purchase database
```

### Logs
```
/var/log/nginx/localai.studio.access.log                   # Nginx access
/var/log/nginx/localai.studio.error.log                    # Nginx errors
/root/localai-studio-marketplace/backup.log                # Backup script logs
```

---

## Quick Reference Commands

```bash
# Status check
./health-check.sh

# Start services
docker compose -f docker-compose.production.yml up -d

# Stop services
docker compose -f docker-compose.production.yml down

# View logs
docker compose -f docker-compose.production.yml logs -f

# Restart service
docker compose -f docker-compose.production.yml restart <service>

# Pull model
docker exec localai-ollama ollama pull <model-name>

# List models
docker exec localai-ollama ollama list

# Database query
sqlite3 /root/localai-studio-marketplace/data/backend/purchases.db "SELECT * FROM purchases;"

# Backup
tar -czf backup_$(date +%Y%m%d).tar.gz data/ .env

# Clean Docker
docker system prune -af

# Reload Nginx
systemctl reload nginx

# Renew SSL
certbot renew
```

---

## Support & Troubleshooting

If you encounter issues:
1. Run `./health-check.sh` to identify the problem
2. Check logs: `docker compose -f docker-compose.production.yml logs -f`
3. Verify database: `ls -lh /root/localai-studio-marketplace/data/backend/`
4. Test connectivity: `curl http://localhost:8000/health`
5. Check resources: `docker stats`

Common issues:
- **Database not persisting**: Check volume mounts and file permissions
- **Ollama connection failed**: Verify service health and network connectivity
- **502 Bad Gateway**: Backend not responding - check logs and restart
- **SSL errors**: Verify certificate and Nginx configuration

---

## Production Checklist

Before going live:
- [ ] Database path fixed in backend-chat.py
- [ ] .env configured with production values
- [ ] SSL certificate installed and valid
- [ ] Firewall rules configured
- [ ] Backup script in crontab
- [ ] Health check script tested
- [ ] All containers healthy
- [ ] TinyLlama model pulled
- [ ] Stripe webhook configured (if using payments)
- [ ] Domain DNS pointing to VPS IP
- [ ] Nginx access logs rotating
- [ ] Monitoring alerts configured

---

**Last Updated:** 2025-11-17
**VPS IP:** 31.220.109.75
**Domain:** localai.studio
