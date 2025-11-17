# Local AI Studio - $0.99 Model Marketplace

Production-ready AI marketplace with per-model purchases.

## 🚀 Quick Deploy to VPS

**1. Clone on VPS:**
```bash
cd /root
git clone https://github.com/willmeldman/localai-studio-marketplace.git
cd localai-studio-marketplace
```

**2. Install Dependencies:**
```bash
apt-get update && apt-get install -y python3-pip python3-venv
python3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn httpx python-dotenv
```

**3. Create Environment File:**
```bash
cat > .env << 'EOF'
SKIP_PAYMENT=false
STRIPE_SECRET_KEY=sk_test_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER
OLLAMA_BASE_URL=http://localhost:11434
EOF
```

**4. Create Systemd Service:**
```bash
cat > /etc/systemd/system/localai-backend.service << 'EOF'
[Unit]
Description=Local AI Studio Backend
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/localai-studio-marketplace
ExecStart=/root/localai-studio-marketplace/venv/bin/python /root/localai-studio-marketplace/backend-chat.py
Restart=always
RestartSec=10
StandardOutput=append:/root/localai-studio-marketplace/backend.log
StandardError=append:/root/localai-studio-marketplace/backend.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable localai-backend.service
systemctl start localai-backend.service
```

**5. Configure Nginx:**
```bash
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /root/localai-studio-marketplace;
    index local-ai-studio-with-affiliates.html;

    location / {
        try_files $uri $uri/ /local-ai-studio-with-affiliates.html;
    }

    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

systemctl restart nginx
```

**6. Set Permissions:**
```bash
chmod 755 /root
chmod 755 /root/localai-studio-marketplace
chmod 644 /root/localai-studio-marketplace/*.html
```

## 🧪 Verify

```bash
curl http://localhost:8000/api/health
curl http://localhost/
```

Visit: http://YOUR_VPS_IP

## 📋 Files

- `local-ai-studio-with-affiliates.html` - Frontend marketplace UI
- `backend-chat.py` - FastAPI backend with purchase tracking

## 💰 Models Available

- **Free:** TinyLlama 1.1B (pre-installed)
- **$0.99 each:** Llama 3.2 3B, Gemma 2 2B, Phi-3.5 Mini, Qwen 2.5 7B, Mistral 7B, DeepSeek Coder, Codestral, Llama 3.1 8B
