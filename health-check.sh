#!/bin/bash
#################################################
# Local AI Studio - Health Check & Monitoring
#################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/root/localai-studio-marketplace"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.production.yml"

echo "=========================================="
echo "Local AI Studio - Health Check"
echo "=========================================="

# Function to check HTTP endpoint
check_http() {
    local url=$1
    local name=$2
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)

    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓${NC} $name: ${GREEN}HEALTHY${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗${NC} $name: ${RED}UNHEALTHY${NC} (HTTP $response)"
        return 1
    fi
}

# Function to check container health
check_container() {
    local container=$1
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)

    if [ "$status" = "healthy" ]; then
        echo -e "${GREEN}✓${NC} $container: ${GREEN}HEALTHY${NC}"
        return 0
    elif [ "$status" = "starting" ]; then
        echo -e "${YELLOW}⚠${NC} $container: ${YELLOW}STARTING${NC}"
        return 1
    else
        echo -e "${RED}✗${NC} $container: ${RED}UNHEALTHY${NC} (status: $status)"
        return 1
    fi
}

# 1. Container Status
echo -e "\n${BLUE}[1] Container Status${NC}"
docker compose -f "$COMPOSE_FILE" ps

# 2. Health Checks
echo -e "\n${BLUE}[2] Container Health${NC}"
check_container "localai-ollama"
check_container "localai-backend"
check_container "localai-frontend"

# 3. HTTP Endpoints
echo -e "\n${BLUE}[3] HTTP Endpoints${NC}"
check_http "http://localhost:8000/health" "Backend API"
check_http "http://localhost:3000" "Frontend"

# 4. Ollama Models
echo -e "\n${BLUE}[4] Ollama Models${NC}"
if docker exec localai-ollama ollama list 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Ollama responding"
else
    echo -e "${RED}✗${NC} Ollama not responding"
fi

# 5. Database Check
echo -e "\n${BLUE}[5] Database Status${NC}"
DB_PATH="/root/localai-studio-marketplace/data/backend/purchases.db"
if [ -f "$DB_PATH" ]; then
    DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
    DB_RECORDS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM purchases;" 2>/dev/null || echo "N/A")
    echo -e "${GREEN}✓${NC} Database exists: $DB_SIZE"
    echo "  Location: $DB_PATH"
    echo "  Purchases: $DB_RECORDS records"
else
    echo -e "${YELLOW}⚠${NC} Database not found (will be created on first purchase)"
fi

# 6. Resource Usage
echo -e "\n${BLUE}[6] Resource Usage${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
    localai-ollama localai-backend localai-frontend 2>/dev/null || echo "Docker stats unavailable"

# 7. Network Status
echo -e "\n${BLUE}[7] Network Connectivity${NC}"
docker exec localai-backend curl -s http://ollama:11434/api/tags > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Backend can reach Ollama"
else
    echo -e "${RED}✗${NC} Backend cannot reach Ollama"
fi

# 8. Disk Usage
echo -e "\n${BLUE}[8] Volume Storage${NC}"
OLLAMA_SIZE=$(du -sh /root/localai-studio-marketplace/data/ollama 2>/dev/null | cut -f1 || echo "N/A")
BACKEND_SIZE=$(du -sh /root/localai-studio-marketplace/data/backend 2>/dev/null | cut -f1 || echo "N/A")
echo "  Ollama data:  $OLLAMA_SIZE"
echo "  Backend data: $BACKEND_SIZE"

# 9. Recent Logs
echo -e "\n${BLUE}[9] Recent Errors (last 20 lines)${NC}"
docker compose -f "$COMPOSE_FILE" logs --tail=20 | grep -i error || echo "No recent errors"

echo ""
echo "=========================================="
echo "Full logs: docker compose -f $COMPOSE_FILE logs -f"
echo "=========================================="
