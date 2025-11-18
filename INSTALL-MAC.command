#!/bin/bash
# Local AI Studio - Mac Double-Click Installer
# Double-click this file in Finder to install

cd "$(dirname "$0")"

echo "============================================="
echo "  LOCAL AI STUDIO - INSTALLATION"
echo "============================================="
echo ""
echo "Installing your private AI playground..."
echo ""

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo ""
    echo "Please install Docker Desktop first:"
    echo "  https://docs.docker.com/desktop/install/mac-install/"
    echo ""
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

echo -e "${GREEN}✓ Docker found${NC}"

# Check if Docker is running
if ! docker ps &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker Desktop is not running${NC}"
    echo ""
    echo "Please start Docker Desktop and try again"
    echo ""
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Create data directories
echo -e "${CYAN}Creating data directories...${NC}"
mkdir -p data/backend
mkdir -p data/ollama
echo -e "${GREEN}✓ Data directories created${NC}"
echo ""

# Start containers
echo -e "${CYAN}Starting Local AI Studio...${NC}"
echo "This may take 1-2 minutes on first run..."
echo ""

docker compose up -d

echo ""
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Wait for services to be ready
echo -e "${CYAN}Waiting for services to start...${NC}"
sleep 10

# Check container status
echo ""
echo "Container Status:"
docker compose ps
echo ""

# Test if frontend is responding
echo -e "${CYAN}Testing frontend...${NC}"
if curl -f -s http://localhost:3000 > /dev/null; then
    echo -e "${GREEN}✓ Frontend is running${NC}"
else
    echo -e "${YELLOW}⚠ Frontend may need more time to start${NC}"
fi

echo ""
echo "============================================="
echo -e "${GREEN}  INSTALLATION COMPLETE! 🎉${NC}"
echo "============================================="
echo ""
echo -e "${CYAN}🌐 Access your AI Studio at:${NC}"
echo "   http://localhost:3000"
echo ""
echo -e "${CYAN}✨ What's included:${NC}"
echo "   • TinyLlama 1.1B (pre-installed & ready)"
echo "   • 10 additional models available"
echo "   • One-click model installation"
echo "   • ChatGPT-like interface"
echo "   • 100% private & local"
echo ""
echo -e "${CYAN}📝 Useful commands:${NC}"
echo "   docker compose ps          # Check status"
echo "   docker compose logs -f     # View logs"
echo "   docker compose stop        # Stop services"
echo "   docker compose restart     # Restart services"
echo ""
echo -e "${GREEN}Opening browser in 3 seconds...${NC}"
sleep 3
open http://localhost:3000

echo ""
echo "Press any key to close this window..."
read -n 1
