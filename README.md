# 🤖 Local AI Studio - Own Your AI Models

**Pay once. Download forever. Run locally.**

No subscriptions. No cloud dependency. Just $0.99 per model.

[![GitHub stars](https://img.shields.io/github/stars/woodman33/localai-studio-marketplace?style=social)](https://github.com/woodman33/localai-studio-marketplace)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://www.docker.com/)

## 🎯 Features

- **💰 Fair Pricing** - $0.99 per model, buy once and own forever
- **🔒 Complete Privacy** - Everything runs on your machine, your data stays local
- **⚡ Lightning Fast** - No API rate limits, no network latency
- **🐳 Docker Ready** - One command deployment with Docker Compose
- **🎨 Beautiful UI** - Clean, modern interface with dark mode
- **🌟 9 Premium Models** - Llama 3.2, Gemma 2, Phi-3.5, Qwen, Mistral, and more

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- 8GB RAM minimum (16GB recommended)
- Mac M1/M2/M3 (Apple Silicon optimized) or x86_64 Linux

### Run Locally in 1 Command

```bash
git clone https://github.com/woodman33/localai-studio-marketplace.git
cd localai-studio-marketplace
cp .env.example .env
docker-compose up -d
```

**Visit:** http://localhost:3000

## 📦 What's Included

- **FastAPI Backend** - Purchase tracking, model management
- **Ollama Engine** - Local LLM inference
- **Beautiful Frontend** - Hero landing page + marketplace
- **Stripe Integration** - Ready for $0.99 payments
- **SQLite Database** - Purchase tracking

## 🔧 Configuration

### Environment Variables

Create a `.env` file:

```bash
# Test Mode (skip payments for development)
SKIP_PAYMENT=true

# Production Stripe Keys (get from https://dashboard.stripe.com)
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Ollama Configuration
OLLAMA_BASE_URL=http://ollama:11434

# Frontend URL for Stripe redirects
FRONTEND_URL=http://localhost:3000
```

### Test Mode

For development, set `SKIP_PAYMENT=true` to test purchases without Stripe.

### Production Mode

1. Get Stripe API keys from https://dashboard.stripe.com
2. Set real keys in `.env`
3. Set `SKIP_PAYMENT=false`
4. Configure Stripe webhook: `https://yourdomain.com/api/stripe/webhook`

## 🎨 Available Models

| Model | Price | Size | Use Case |
|-------|-------|------|----------|
| TinyLlama 1.1B | **FREE** | 637MB | Learning, testing |
| Llama 3.2 3B | $0.99 | 2GB | General chat |
| Gemma 2 2B | $0.99 | 1.6GB | Lightweight assistant |
| Phi-3.5 Mini | $0.99 | 2.2GB | Coding, reasoning |
| Qwen 2.5 7B | $0.99 | 4.7GB | Advanced tasks |
| Mistral 7B | $0.99 | 4.1GB | Production quality |
| DeepSeek Coder | $0.99 | 6.8GB | Code generation |
| Codestral | $0.99 | 12GB | Advanced coding |
| Llama 3.1 8B | $0.99 | 4.7GB | Latest generation |

## 📖 Documentation

- [**DOCKER.md**](DOCKER.md) - Complete Docker deployment guide
- [**API Docs**](http://localhost:8000/docs) - Interactive API documentation (when running)

## 🛠️ Development

### Project Structure

```
localai-studio-marketplace/
├── docker-compose.yml          # Multi-service orchestration
├── Dockerfile.backend          # FastAPI backend container
├── nginx.conf                  # Nginx routing config
├── backend-chat.py             # FastAPI application
├── index.html                  # Hero landing page
├── local-ai-studio-with-affiliates.html  # Marketplace UI
├── requirements.txt            # Python dependencies
└── .env                        # Configuration (create from .env.example)
```

### Local Development

```bash
# Run backend only (for development)
cd localai-studio-marketplace
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn backend-chat:app --reload --port 8000

# In another terminal, start Ollama
docker run -d -p 11434:11434 ollama/ollama

# Open the frontend
open index.html
```

## 🌐 Production Deployment

See [DOCKER.md](DOCKER.md) for complete VPS deployment guide including:
- Hostinger VPS setup
- Domain configuration
- SSL certificates
- Nginx reverse proxy
- Production best practices

## 💳 Stripe Setup

1. Create account at https://dashboard.stripe.com
2. Get your API keys from **Developers → API Keys**
3. Create a webhook endpoint pointing to `/api/stripe/webhook`
4. Copy webhook secret
5. Update `.env` with real keys
6. Restart: `docker-compose restart backend`

## 🧪 Testing

### Test Purchase Flow

1. Visit http://localhost:3000/marketplace
2. Click any "Purchase $0.99 💳" button
3. With `SKIP_PAYMENT=true`, you'll instantly get access
4. Click "Download Model" to trigger Ollama pull
5. Chat with your model!

### API Health Check

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/models/owned
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📝 License

MIT License - see [LICENSE](LICENSE) for details

## 🙏 Credits

Built with:
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python API framework
- [Ollama](https://ollama.ai/) - Run LLMs locally
- [Stripe](https://stripe.com/) - Payment processing
- [Docker](https://www.docker.com/) - Containerization

## 📞 Support

- **Issues:** https://github.com/woodman33/localai-studio-marketplace/issues
- **Discussions:** https://github.com/woodman33/localai-studio-marketplace/discussions

---

**⭐ If you find this useful, give it a star on GitHub!**

Made with ❤️ for the AI community
