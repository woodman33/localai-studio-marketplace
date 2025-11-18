# Local AI Studio - Production Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS (443)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    HOSTINGER VPS (31.220.109.75)                │
│                   Ubuntu 24.04 | 16GB RAM | 4 CPUs              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              Host Nginx (Reverse Proxy)                    │ │
│  │  • SSL/TLS Termination (Let's Encrypt)                    │ │
│  │  • Rate Limiting (API: 10 req/s, General: 30 req/s)       │ │
│  │  • Security Headers (HSTS, CSP, etc.)                     │ │
│  │  • Request Routing                                         │ │
│  └───────────┬──────────────┬────────────────┬────────────────┘ │
│              │              │                │                   │
│              │              │                │                   │
│  ┌───────────▼──────────────▼────────────────▼────────────────┐ │
│  │             Docker Network: localai-network                │ │
│  │                   172.25.0.0/16                            │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │                                                             │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐ │ │
│  │  │   Frontend      │  │    Backend      │  │   Ollama   │ │ │
│  │  │   (Nginx)       │  │   (FastAPI)     │  │  (LLM Srv) │ │ │
│  │  │                 │  │                 │  │            │ │ │
│  │  │ Port: 3000→80   │  │ Port: 8000      │  │ Port: 11434│ │ │
│  │  │ RAM: 256MB      │  │ RAM: 2GB        │  │ RAM: 8GB   │ │ │
│  │  │ CPU: 0.5        │  │ CPU: 2          │  │ CPU: 4     │ │ │
│  │  │                 │  │                 │  │            │ │ │
│  │  │ Serves:         │  │ Handles:        │  │ Provides:  │ │ │
│  │  │ • Landing page  │  │ • /api/* routes │  │ • LLM API  │ │ │
│  │  │ • Marketplace   │  │ • Chat API      │  │ • Models   │ │ │
│  │  │ • Static files  │  │ • Purchases     │  │ • Inference│ │ │
│  │  │                 │  │ • Stripe        │  │            │ │ │
│  │  │                 │  │                 │  │            │ │ │
│  │  │                 │  │ Connects to:    │  │            │ │ │
│  │  │ Proxy to:       │  │ • Ollama ───────┼──►            │ │ │
│  │  │ Backend ────────┼──► • Database      │  │            │ │ │
│  │  │                 │  │ • Stripe API ───┼──┼────────────┼─┼─┤
│  │  └─────────────────┘  └─────┬───────────┘  └────┬───────┘ │ │
│  │                             │                    │         │ │
│  │                             ▼                    ▼         │ │
│  │                    ┌─────────────────┐  ┌─────────────┐  │ │
│  │                    │  Backend Data   │  │ Ollama Data │  │ │
│  │                    │  (Bind Mount)   │  │ (Bind Mount)│  │ │
│  │                    │  purchases.db   │  │   models/   │  │ │
│  │                    └─────────────────┘  └─────────────┘  │ │
│  │                             │                    │         │ │
│  └─────────────────────────────┼────────────────────┼─────────┘ │
│                                │                    │           │
│                                ▼                    ▼           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Host Filesystem (Persistent)               │   │
│  │  /root/localai-studio-marketplace/data/                 │   │
│  │  ├── backend/purchases.db        (SQLite Database)      │   │
│  │  └── ollama/models/              (AI Model Weights)     │   │
│  │                                                          │   │
│  │  /root/backups/localai/                                 │   │
│  │  └── localai_backup_YYYYMMDD.tar.gz  (Daily Backups)   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Request Flow

### 1. Landing Page Request
```
User Browser (HTTPS)
    │
    ▼
Host Nginx (443) → SSL/TLS Decrypt → Rate Limit Check → Security Headers
    │
    ▼
Frontend Container (3000:80) → Serve index.html
    │
    ▼
User Browser ← HTML Response
```

### 2. Marketplace Page Request
```
User Browser (HTTPS)
    │
    ▼
Host Nginx → /marketplace route
    │
    ▼
Frontend Container → Serve marketplace.html
    │
    ▼
User Browser ← Marketplace UI
```

### 3. Chat API Request
```
User Browser
    │
    ▼
POST /api/chat {message: "Hello", model: "tinyllama:latest"}
    │
    ▼
Host Nginx → Rate Limit (10 req/s) → API Proxy
    │
    ▼
Backend Container (8000) → Parse Request → Validate Model
    │
    ▼
HTTP Request to http://ollama:11434/api/generate
    │
    ▼
Ollama Container (11434) → Load Model → Run Inference → Return Response
    │
    ▼
Backend Container → Format Response → Return JSON
    │
    ▼
Host Nginx → Add Security Headers
    │
    ▼
User Browser ← {response: "Hello! How can I help?", model: "tinyllama"}
```

### 4. Model Purchase Flow (Test Mode)
```
User Browser → Click "Buy Model" → POST /api/models/purchase/llama3.2:3b
    │
    ▼
Host Nginx → Rate Limit → API Proxy
    │
    ▼
Backend Container:
    • Check SKIP_PAYMENT=true
    • Generate UUID for purchase
    • Write to SQLite: INSERT INTO purchases (user_id, model_id, ...)
    │
    ▼
SQLite Database (purchases.db in bind mount)
    │
    ▼
Backend ← Success
    │
    ▼
User Browser ← {status: "success", message: "Test purchase successful"}
    │
    ▼
Frontend → Update UI → Show "Install Model" button
```

### 5. Model Installation Flow
```
User Browser → Click "Install" → POST /api/models/install {model: "llama3.2:3b"}
    │
    ▼
Backend Container:
    • Validate model name
    • Call Ollama API: POST http://ollama:11434/api/pull
    │
    ▼
Ollama Container:
    • Download model from Ollama Hub
    • Save to /root/.ollama/models/ (bind mount)
    • Extract and prepare
    │
    ▼
Host Filesystem: /root/localai-studio-marketplace/data/ollama/models/
    │
    ▼
Backend ← {status: "success"}
    │
    ▼
User Browser ← Installation complete
```

---

## Data Persistence Architecture

### Why Bind Mounts Over Named Volumes?

**Named Volumes (Standard Docker):**
```
docker volume create backend-data
└── Stored in: /var/lib/docker/volumes/backend-data/_data/
    • Opaque location
    • Requires docker cp for access
    • Harder to backup
    • Less transparent
```

**Bind Mounts (Our Approach):**
```
/root/localai-studio-marketplace/data/backend/
├── purchases.db
└── [Future: logs, uploads, etc.]
    • Direct filesystem access
    • Easy backups: tar -czf backup.tar.gz data/
    • Simple sqlite3 queries: sqlite3 data/backend/purchases.db
    • Transparent storage monitoring: du -sh data/
```

### Volume Mappings

```yaml
services:
  backend:
    volumes:
      - /root/localai-studio-marketplace/data/backend:/app/data
        # Host path ───────────────────────────────┘  └─── Container path
        # purchases.db saved here                       Backend sees /app/data/

  ollama:
    volumes:
      - /root/localai-studio-marketplace/data/ollama:/root/.ollama
        # Host path ──────────────────────────────┘  └─── Container path
        # Models saved here                            Ollama sees /root/.ollama/
```

---

## Security Architecture

### Network Isolation

```
Internet
    │
    ▼
Host Firewall (UFW)
    • Allow: 22 (SSH), 80 (HTTP), 443 (HTTPS)
    • Deny: 3000, 8000, 11434 (Container ports)
    │
    ▼
Host Nginx (127.0.0.1:3000, 127.0.0.1:8000)
    • Containers bind to localhost only
    • Not exposed to internet directly
    │
    ▼
Docker Network (172.25.0.0/16)
    • Isolated internal network
    • Containers can communicate
    • No direct internet access
```

### Security Layers

1. **SSL/TLS:** All public traffic encrypted (Let's Encrypt)
2. **Rate Limiting:** API abuse prevention (10 req/s)
3. **Security Headers:** XSS, clickjacking protection
4. **Non-Root Containers:** Backend runs as UID 1000
5. **Port Binding:** Containers on 127.0.0.1 only
6. **Network Isolation:** Docker bridge network
7. **Input Validation:** Model name sanitization
8. **Stripe Webhook:** Signature verification

---

## Resource Allocation Strategy

### Total Available: 16GB RAM, 4 CPUs

**Allocation:**
```
┌─────────────────────────────────────────┐
│ Ollama Container:  8GB RAM, 4 CPUs     │  ← 50% of resources
│ (Adjustable based on model size)       │
├─────────────────────────────────────────┤
│ Backend Container: 2GB RAM, 2 CPUs     │  ← 12.5% of resources
│ (FastAPI + SQLite is lightweight)      │
├─────────────────────────────────────────┤
│ Frontend Container: 256MB, 0.5 CPUs    │  ← 1.6% of resources
│ (Nginx is extremely efficient)         │
├─────────────────────────────────────────┤
│ System Reserved:   ~6GB RAM, 1.5 CPUs  │  ← 37.5% buffer
│ (OS, monitoring, buffers, etc.)        │
└─────────────────────────────────────────┘
```

**Why These Limits?**
- Ollama needs most RAM for model weights (3B model ≈ 2-4GB, 7B ≈ 4-8GB)
- FastAPI is async, handles 100+ concurrent requests with 2GB
- Nginx can handle 10K+ req/s with 256MB
- 6GB buffer prevents OOM kills and allows headroom

**Adjusting Limits:**
Edit `docker-compose.production.yml`:
```yaml
services:
  ollama:
    deploy:
      resources:
        limits:
          memory: 12G  # Increase for larger models
          cpus: '6.0'  # More CPUs = faster inference
```

---

## Monitoring Architecture

### Health Check Hierarchy

```
Layer 1: Docker Health Checks (Built-in)
├── Ollama:   Runs every 30s → ollama list
├── Backend:  Runs every 30s → curl localhost:8000/health
└── Frontend: Runs every 30s → wget localhost:80

Layer 2: Automated Script (health-check.sh)
├── Container status check
├── HTTP endpoint verification
├── Database integrity check
├── Resource usage snapshot
└── Error log scanning

Layer 3: Cron Monitoring (backup-and-monitor.sh)
├── Daily at 2 AM
├── Health checks + automatic restart
├── Disk space monitoring
├── Database backups
└── Email alerts (optional)

Layer 4: External Monitoring (Optional)
├── UptimeRobot → Check https://localai.studio every 5 min
├── Grafana + Loki → Log aggregation
└── Email/Slack → Alert on downtime
```

### Health Check Endpoints

```
# Internal (Docker health checks)
http://localhost:8000/health  → Backend API
http://localhost:3000         → Frontend Nginx
ollama list                   → Ollama service

# External (Uptime monitoring)
https://localai.studio/health  → Public health endpoint
```

---

## Backup Architecture

### Backup Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                     Daily Backup (2 AM)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Source:                                                     │
│  /root/localai-studio-marketplace/                          │
│  ├── data/backend/purchases.db       (SQLite Database)      │
│  ├── data/ollama/models/             (AI Models - Optional) │
│  ├── .env                            (Configuration)        │
│  └── docker-compose.production.yml   (Infrastructure)       │
│                                                              │
│  ▼ tar -czf (Compressed Archive)                            │
│                                                              │
│  Destination:                                                │
│  /root/backups/localai/localai_backup_YYYYMMDD_HHMMSS.tar.gz│
│                                                              │
│  Retention:                                                  │
│  • Keep last 7 days of backups                              │
│  • Auto-delete older backups                                │
│  • Typical size: 10-500MB (without Ollama models)           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Disaster Recovery

**Scenario: VPS Failure**
1. Provision new VPS
2. Install Docker, Nginx
3. Transfer latest backup: `scp backup.tar.gz root@new-vps:/root/`
4. Extract: `tar -xzf backup.tar.gz`
5. Run: `./deploy-vps.sh`
6. Update DNS to new VPS IP
7. Ollama models re-downloaded automatically (or restored from backup)

**Recovery Time Objective (RTO):** 15 minutes (without model downloads)

---

## Deployment Architecture

### Build Process

```
Local Mac
    │
    ▼
Code Changes → Git Commit → Git Push
    │
    ▼
VPS: git pull
    │
    ▼
Docker Build (Multi-stage)
    │
    ├─ Stage 1: Builder
    │  • Install build dependencies (gcc, etc.)
    │  • pip install packages
    │  • Create wheel files
    │
    └─ Stage 2: Production
       • Copy only wheels (not build deps)
       • Create non-root user
       • Set permissions
       • Copy application code
       • Configure entrypoint
    │
    ▼
Docker Image (Optimized)
    • Smaller size (no build tools)
    • Faster startup
    • More secure (non-root)
    │
    ▼
Docker Compose Up
    • Pull/Build images
    • Create network
    • Create volumes
    • Start containers
    • Health checks
    • Service ready
```

### CI/CD Ready (Future)

```
GitHub Actions / GitLab CI
    │
    ▼
Run Tests → Build Docker → Push to Registry → SSH to VPS → Pull & Deploy
```

---

## Scaling Architecture (Future)

### Horizontal Scaling (When Needed)

```
Current: Single VPS
┌─────────────────────┐
│  Nginx + 3 Containers│
└─────────────────────┘

Future: Load Balanced
┌─────────────┐
│ Load Balancer│
└──────┬───────┘
       │
   ┌───┴───┐
   │       │
┌──▼──┐ ┌──▼──┐
│ VPS1│ │ VPS2│
│ 3x  │ │ 3x  │
│ Cont│ │ Cont│
└─────┘ └─────┘
   │       │
   └───┬───┘
       │
  ┌────▼────┐
  │Shared DB│
  │(PostgreSQL)│
  └─────────┘
```

**When to Scale:**
- Concurrent users > 100
- Chat requests > 50/sec
- Ollama queue depth > 10
- CPU consistently > 80%

**Migration Path:**
1. SQLite → PostgreSQL (data export)
2. Single VPS → Multi-VPS (DNS load balancing)
3. Local models → Cloud API hybrid (cost optimization)

---

## Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────┐
│                       Technology Stack                       │
├─────────────────────────────────────────────────────────────┤
│ Frontend:     Nginx (Alpine), HTML/CSS/JS, Static files    │
│ Backend:      FastAPI 0.109, Python 3.11, Uvicorn          │
│ Database:     SQLite3 (file-based, ACID transactions)      │
│ AI Engine:    Ollama (latest), TinyLlama, Llama 3.2, etc.  │
│ Container:    Docker 24+, Docker Compose V2                │
│ Proxy:        Nginx (host), Let's Encrypt SSL              │
│ OS:           Ubuntu 24.04 LTS                              │
│ Monitoring:   Bash scripts, Docker health checks           │
│ Backup:       Cron + tar, 7-day retention                  │
│ Payment:      Stripe API 7.10 (test mode / production)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Performance Characteristics

**Expected Performance (16GB VPS):**
- Concurrent users: 50-100
- Chat latency: 1-5 seconds (depends on model)
- Marketplace page load: < 500ms
- API response time: < 100ms (non-AI endpoints)
- Database queries: < 10ms
- Model installation: 2-10 minutes (depends on model size)

**Bottlenecks:**
1. Ollama inference (GPU would help)
2. Model download bandwidth
3. Disk I/O for model loading

**Optimizations Applied:**
- HTTP/2 (multiplexing)
- Keepalive connections
- Log rotation
- Resource limits
- Multi-worker backend

---

**Created:** 2025-11-17
**Architecture Type:** Microservices (3 containers)
**Deployment Model:** Single VPS, Docker Compose
**High Availability:** Not yet (single point of failure)
**Scalability:** Vertical (upgrade VPS) or Horizontal (add VPS + load balancer)
