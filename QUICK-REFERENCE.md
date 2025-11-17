# Local AI Studio Marketplace - Quick Reference Card

## Deploy in 30 Seconds

```bash
cd /root && \
git clone https://github.com/woodman33/localai-studio-marketplace.git && \
cd localai-studio-marketplace && \
bash deploy-to-vps.sh
```

---

## Essential Commands

### Status Check
```bash
cd /root/localai-studio-marketplace
docker ps
docker compose -f docker-compose.vps.yml ps
```

### View Logs
```bash
docker compose -f docker-compose.vps.yml logs -f
docker compose -f docker-compose.vps.yml logs -f backend
docker compose -f docker-compose.vps.yml logs -f frontend
```

### Restart Services
```bash
docker compose -f docker-compose.vps.yml restart
docker compose -f docker-compose.vps.yml restart backend
docker compose -f docker-compose.vps.yml restart frontend
```

### Stop/Start
```bash
docker compose -f docker-compose.vps.yml down
docker compose -f docker-compose.vps.yml up -d
```

### Update Code
```bash
cd /root/localai-studio-marketplace
git pull
docker compose -f docker-compose.vps.yml up -d --build
```

---

## Test Endpoints

```bash
# Backend health
curl http://localhost:8000/health

# Frontend
curl -I http://localhost:3001

# Ollama
curl http://localhost:11434/api/tags

# HTTPS (external)
curl -I https://localai.studio

# Open WebUI
curl -I http://localhost:3000
```

---

## Port Reference

- **3000** - Open WebUI (existing)
- **3001** - Marketplace Frontend
- **8000** - Marketplace Backend
- **11434** - Ollama (shared)
- **80** - Nginx HTTP (redirects)
- **443** - Nginx HTTPS (main)

---

## URLs

- **Marketplace**: https://localai.studio
- **Open WebUI**: http://31.220.109.75:3000
- **Backend API**: http://localhost:8000/health (internal only)

---

## File Locations

- **Config**: `/root/localai-studio-marketplace/`
- **Database**: `/root/localai-studio-marketplace/data/backend/purchases.db`
- **Nginx**: `/etc/nginx/sites-available/localai.studio`
- **SSL**: `/etc/letsencrypt/live/localai.studio/`
- **Logs**: `docker compose logs` or `/var/log/nginx/`

---

## Quick Fixes

### Container Won't Start
```bash
docker compose -f docker-compose.vps.yml down
docker compose -f docker-compose.vps.yml up -d --force-recreate
```

### 502 Bad Gateway
```bash
docker compose -f docker-compose.vps.yml restart
nginx -t && systemctl reload nginx
```

### SSL Issues
```bash
certbot renew --nginx
systemctl reload nginx
```

### Full Reset
```bash
cd /root/localai-studio-marketplace
docker compose -f docker-compose.vps.yml down -v
git pull
bash deploy-to-vps.sh
```

---

## Verification

```bash
cd /root/localai-studio-marketplace
bash verify-deployment.sh
```

---

## Support

- **Deployment Guide**: [VPS-DEPLOYMENT-INSTRUCTIONS.md](VPS-DEPLOYMENT-INSTRUCTIONS.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **GitHub**: https://github.com/woodman33/localai-studio-marketplace

---

## Emergency Contacts

- **VPS IP**: 31.220.109.75
- **SSH**: Via Terminus app as root
- **Domain**: localai.studio
- **DNS**: Managed at domain registrar

---

**Print this card and keep it handy!**
