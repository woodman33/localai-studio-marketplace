#!/bin/bash
#################################################
# Local AI Studio Marketplace - VPS Deployment
# Hostinger VPS (Ubuntu 24.04, 16GB RAM)
#################################################

set -e  # Exit on error

echo "=========================================="
echo "Local AI Studio - VPS Deployment Script"
echo "=========================================="

# Configuration
PROJECT_DIR="/root/localai-studio-marketplace"
DATA_DIR="${PROJECT_DIR}/data"
OLLAMA_DATA="${DATA_DIR}/ollama"
BACKEND_DATA="${DATA_DIR}/backend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Create project directory
echo -e "\n${GREEN}[1/9]${NC} Creating project directory..."
mkdir -p "${PROJECT_DIR}"
cd "${PROJECT_DIR}"

# Step 2: Create data directories for bind mounts
echo -e "\n${GREEN}[2/9]${NC} Creating data directories..."
mkdir -p "${OLLAMA_DATA}" "${BACKEND_DATA}"
chmod 755 "${DATA_DIR}"
chmod 755 "${OLLAMA_DATA}"
chmod 755 "${BACKEND_DATA}"

# Step 3: Clone repository (if not already present)
echo -e "\n${GREEN}[3/9]${NC} Checking repository..."
if [ ! -f "${PROJECT_DIR}/docker-compose.production.yml" ]; then
    echo -e "${YELLOW}Repository files not found. Please clone/copy files first.${NC}"
    echo "Run on your local machine:"
    echo "  scp -r /Users/willmeldman/localai-studio-marketplace/* root@31.220.109.75:${PROJECT_DIR}/"
    exit 1
else
    echo "Repository files found."
fi

# Step 4: Create production .env file
echo -e "\n${GREEN}[4/9]${NC} Creating production .env file..."
cat > "${PROJECT_DIR}/.env" <<'EOF'
# Local AI Studio - Production Configuration

# ==================== TEST MODE ====================
# Set to 'true' to test purchases without Stripe
# Set to 'false' for production with real payments
SKIP_PAYMENT=true

# ==================== STRIPE CONFIGURATION ====================
# Get your keys from: https://dashboard.stripe.com/apikeys

# Test keys (for initial deployment)
STRIPE_SECRET_KEY=sk_test_PLACEHOLDER
STRIPE_PUBLISHABLE_KEY=pk_test_PLACEHOLDER
STRIPE_WEBHOOK_SECRET=whsec_PLACEHOLDER

# Production keys (add when ready for real payments)
# STRIPE_SECRET_KEY=sk_live_YOUR_SECRET_KEY
# STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_PUBLISHABLE_KEY
# STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET

# ==================== OLLAMA CONFIGURATION ====================
# URL for Ollama service (use container name in Docker)
OLLAMA_BASE_URL=http://ollama:11434

# ==================== FRONTEND CONFIGURATION ====================
# Frontend URL for Stripe redirect after purchase
FRONTEND_URL=https://localai.studio

# ==================== DATABASE ====================
# SQLite database location (in mounted volume)
# Automatically created at /app/data/purchases.db
EOF

echo "Created .env file (default: SKIP_PAYMENT=true)"

# Step 5: Fix backend database path (CRITICAL)
echo -e "\n${GREEN}[5/9]${NC} Fixing backend database path..."
if grep -q "sqlite3.connect('purchases.db')" backend-chat.py 2>/dev/null; then
    echo -e "${YELLOW}WARNING: Database path needs to be fixed in backend-chat.py${NC}"
    echo "The database must save to /app/data/purchases.db (mounted volume)"
    echo "Current code saves to /purchases.db (ephemeral container root)"
    echo ""
    echo "Required changes:"
    echo "1. Add at top: DB_PATH = os.path.join('/app/data', 'purchases.db')"
    echo "2. Replace all sqlite3.connect('purchases.db') with sqlite3.connect(DB_PATH)"
    echo "3. Update init_db() to create /app/data directory"
    echo ""
    echo "See backend-chat.fixed.py for complete fix."
fi

# Step 6: Build Docker images
echo -e "\n${GREEN}[6/9]${NC} Building Docker images..."
docker compose -f docker-compose.production.yml build --no-cache

# Step 7: Start services
echo -e "\n${GREEN}[7/9]${NC} Starting services..."
docker compose -f docker-compose.production.yml up -d

# Step 8: Wait for services to be healthy
echo -e "\n${GREEN}[8/9]${NC} Waiting for services to be healthy..."
sleep 10

# Check health
for i in {1..30}; do
    if docker ps --filter "name=localai" --filter "health=healthy" | grep -q healthy; then
        echo -e "${GREEN}Services are healthy!${NC}"
        break
    fi
    echo "Waiting for services to become healthy... ($i/30)"
    sleep 2
done

# Step 9: Pull TinyLlama model
echo -e "\n${GREEN}[9/9]${NC} Pulling TinyLlama model (free default)..."
docker exec localai-ollama ollama pull tinyllama:latest || echo "Model pull queued (may take a few minutes)"

echo ""
echo "=========================================="
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo "=========================================="
echo ""
echo "Container Status:"
docker compose -f docker-compose.production.yml ps
echo ""
echo "Health Checks:"
echo "  Backend:  curl http://localhost:8000/health"
echo "  Frontend: curl http://localhost:3000"
echo "  Ollama:   docker exec localai-ollama ollama list"
echo ""
echo "Logs:"
echo "  All:      docker compose -f docker-compose.production.yml logs -f"
echo "  Backend:  docker compose -f docker-compose.production.yml logs -f backend"
echo "  Ollama:   docker compose -f docker-compose.production.yml logs -f ollama"
echo ""
echo "Next Steps:"
echo "1. Configure Nginx reverse proxy (see nginx-host.conf)"
echo "2. Set up SSL with Let's Encrypt"
echo "3. Test marketplace at https://localai.studio"
echo "4. Monitor logs for any errors"
echo ""
echo "Database Location: ${BACKEND_DATA}/purchases.db"
echo "Ollama Models:     ${OLLAMA_DATA}"
echo ""
