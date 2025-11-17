# 🐳 Docker Deployment Guide

Complete guide for deploying Local AI Studio with Docker on any platform.

## Table of Contents

- [Local Development](#local-development-mac-m4)
- [VPS Production Deployment](#vps-production-deployment)
- [Hostinger VPS Setup](#hostinger-vps-specific-guide)
- [Troubleshooting](#troubleshooting)

---

## Local Development (Mac M4)

### Prerequisites

- Docker Desktop for Mac (with Apple Silicon support)
- 16GB RAM recommended
- 20GB free disk space

### Quick Start

```bash
# Clone the repository
git clone https://github.com/woodman33/localai-studio-marketplace.git
cd localai-studio-marketplace

# Create environment file
cp .env.example .env

# Edit .env - set SKIP_PAYMENT=true for testing
nano .env

# Start all services
docker-compose up -d

# Watch logs
docker-compose logs -f

# Visit the application
open http://localhost:3000
```

### Services

After running `docker-compose up -d`, you'll have:

| Service | Port | URL |
|---------|------|-----|
| Frontend (Nginx) | 3000 | http://localhost:3000 |
| Backend (FastAPI) | 8000 | http://localhost:8000 |
| Ollama | 11434 | http://localhost:11434 |
| API Docs | 8000 | http://localhost:8000/docs |

### Useful Commands

```bash
# Stop all services
docker-compose down

# Restart a service
docker-compose restart backend

# View logs for specific service
docker-compose logs -f backend

# Execute command in Ollama
docker exec -it localai-ollama ollama list
docker exec -it localai-ollama ollama pull llama3.2:3b

# Check service status
docker-compose ps

# Rebuild after code changes
docker-compose up -d --build
```

---

## VPS Production Deployment

### Prerequisites

- VPS with Ubuntu 24.04 LTS
- Root or sudo access
- Domain pointed to VPS IP
- 8GB RAM minimum (16GB recommended)
- 50GB disk space

### Step 1: Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose -y

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
docker --version
docker-compose --version
```

### Step 2: Clone and Configure

```bash
# Clone repository
cd /root
git clone https://github.com/woodman33/localai-studio-marketplace.git
cd localai-studio-marketplace

# Create environment file
cp .env.example .env

# Edit configuration
nano .env
```

Set these values in `.env`:

```bash
# For testing without payments
SKIP_PAYMENT=true

# For production with real Stripe
SKIP_PAYMENT=false
STRIPE_SECRET_KEY=sk_live_YOUR_KEY
STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_KEY
STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET

# Ollama (keep default)
OLLAMA_BASE_URL=http://ollama:11434

# Frontend URL (use your domain)
FRONTEND_URL=https://localai.studio
```

### Step 3: Start Services

```bash
# Start all containers
docker-compose up -d

# Check status
docker-compose ps

# Watch logs
docker-compose logs -f
```

### Step 4: Configure Nginx Reverse Proxy

```bash
# Install Nginx
sudo apt install nginx -y

# Create site config
sudo nano /etc/nginx/sites-available/localai
```

Add this configuration:

```nginx
server {
    listen 80;
    server_name localai.studio www.localai.studio;

    # Landing page
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API
    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/localai /etc/nginx/sites-enabled/

# Remove default
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### Step 5: SSL Certificate (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Get certificate
sudo certbot --nginx -d localai.studio -d www.localai.studio

# Auto-renewal
sudo certbot renew --dry-run
```

### Step 6: Verify Deployment

```bash
# Check all services running
docker-compose ps

# Test backend API
curl http://localhost:8000/health

# Test frontend
curl -I http://localhost:3000

# View logs
docker-compose logs -f backend
```

---

## Hostinger VPS Specific Guide

### Initial Setup

1. **Purchase VPS**: Get KVM 4 or higher (16GB RAM recommended)
2. **Access**: Use Hostinger's browser terminal or SSH via Terminus app
3. **IP Address**: Note your VPS IP (e.g., 31.220.109.75)

### DNS Configuration

In Hostinger DNS management:

```
A     @              31.220.109.75     (TTL: 3600)
A     www            31.220.109.75     (TTL: 3600)
CNAME marketplace     localai.studio    (TTL: 3600)
```

### Deployment Commands

Copy/paste these commands into **VPS TERMINAL**:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh

# Install Docker Compose
apt install docker-compose -y

# Clone repository
cd /root
git clone https://github.com/woodman33/localai-studio-marketplace.git
cd localai-studio-marketplace

# Create environment
echo "SKIP_PAYMENT=true" > .env
echo "OLLAMA_BASE_URL=http://ollama:11434" >> .env
echo "STRIPE_SECRET_KEY=sk_test_PLACEHOLDER" >> .env
echo "STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER" >> .env
echo "STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER" >> .env
echo "FRONTEND_URL=http://31.220.109.75:3000" >> .env

# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### Installing Nginx

```bash
# Install
apt update && apt install nginx -y

# Create config
cat > /etc/nginx/sites-available/localai << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/localai /etc/nginx/sites-enabled/

# Test and restart
nginx -t
systemctl restart nginx
```

### Verify Deployment

Visit in browser:
- **Landing page**: http://31.220.109.75
- **Marketplace**: http://31.220.109.75/marketplace
- **API health**: http://31.220.109.75/api/health

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs backend

# Rebuild container
docker-compose up -d --build backend

# Check disk space
df -h

# Check memory
free -h
```

### Ollama Not Responding

```bash
# Check if running
docker ps | grep ollama

# Restart Ollama
docker-compose restart ollama

# Check logs
docker-compose logs ollama

# Pull a model to test
docker exec -it localai-ollama ollama pull tinyllama
```

### Backend API Errors

```bash
# Check environment variables
docker exec localai-backend env | grep STRIPE

# Check database
docker exec localai-backend ls -la /app/data/

# Restart backend
docker-compose restart backend

# View real-time logs
docker-compose logs -f backend
```

### Frontend Not Loading

```bash
# Check nginx container
docker ps | grep nginx

# Check nginx logs
docker-compose logs frontend

# Test directly
curl http://localhost:3000

# Rebuild frontend
docker-compose up -d --build frontend
```

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>

# Or change port in docker-compose.yml
ports:
  - "3001:80"  # Use different port
```

### Database Issues

```bash
# Check database file
docker exec localai-backend ls -la /app/data/purchases.db

# Reset database (WARNING: deletes all purchases)
docker-compose down
docker volume rm localai-studio-marketplace_backend-data
docker-compose up -d
```

### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificate
sudo certbot renew --force-renewal

# Check Nginx config
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### Complete Reset

```bash
# Stop and remove everything
docker-compose down -v

# Remove all images
docker rmi $(docker images -q localai-*)

# Clean rebuild
docker-compose up -d --build

# Check status
docker-compose ps
docker-compose logs -f
```

---

## Performance Optimization

### For Mac M4

```yaml
# In docker-compose.yml, add platform specification
services:
  ollama:
    platform: linux/arm64
    # ... rest of config
```

### Memory Limits

```yaml
# Add to docker-compose.yml
services:
  ollama:
    deploy:
      resources:
        limits:
          memory: 8G
```

### Storage Optimization

```bash
# Clean unused Docker data
docker system prune -a

# Monitor disk usage
docker system df
```

---

## Monitoring

### Health Checks

```bash
# Backend health
curl http://localhost:8000/health

# Ollama status
curl http://localhost:11434/api/tags

# Container stats
docker stats
```

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend

# Last 100 lines
docker-compose logs --tail=100 backend

# Follow new logs only
docker-compose logs -f --tail=0
```

---

## Updating

### Pull Latest Changes

```bash
# On VPS
cd /root/localai-studio-marketplace
git pull origin main

# Rebuild and restart
docker-compose up -d --build

# Check status
docker-compose ps
```

### Backup Before Update

```bash
# Backup database
docker cp localai-backend:/app/data/purchases.db ./backup_$(date +%Y%m%d).db

# Backup env file
cp .env .env.backup
```

---

## Security Best Practices

1. **Use strong Stripe keys** - Never commit real keys to Git
2. **Enable firewall** - Allow only ports 80, 443, and SSH
3. **Regular updates** - Keep Docker and system updated
4. **Monitor logs** - Watch for suspicious activity
5. **Backup database** - Regular backups of purchases.db
6. **Use SSL** - Always use HTTPS in production
7. **Restrict SSH** - Use key-based auth, disable password login

---

## Production Checklist

- [ ] Docker and Docker Compose installed
- [ ] Repository cloned
- [ ] `.env` configured with real Stripe keys
- [ ] `SKIP_PAYMENT=false` for production
- [ ] All services running (`docker-compose ps`)
- [ ] Nginx reverse proxy configured
- [ ] SSL certificate installed
- [ ] Domain DNS pointing to VPS
- [ ] Firewall configured
- [ ] Backup system in place
- [ ] Monitoring setup
- [ ] Stripe webhook configured
- [ ] Test purchase flow working

---

**Need help?** Open an issue: https://github.com/woodman33/localai-studio-marketplace/issues
