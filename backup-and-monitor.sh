#!/bin/bash
#################################################
# Local AI Studio - Backup & Monitoring Script
# Add to crontab: 0 2 * * * /root/localai-studio-marketplace/backup-and-monitor.sh
#################################################

set -e

# Configuration
PROJECT_DIR="/root/localai-studio-marketplace"
BACKUP_DIR="/root/backups/localai"
DATA_DIR="${PROJECT_DIR}/data"
RETENTION_DAYS=7
LOG_FILE="${PROJECT_DIR}/backup.log"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/localai_backup_${TIMESTAMP}.tar.gz"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Starting backup and monitoring..."
log "=========================================="

# 1. Backup database and configuration
log "[1/6] Backing up data..."
tar -czf "$BACKUP_FILE" \
    -C "$PROJECT_DIR" \
    data/ \
    .env \
    docker-compose.production.yml \
    2>/dev/null || log "WARNING: Some files missing from backup"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# 2. Remove old backups
log "[2/6] Removing backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "localai_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/localai_backup_*.tar.gz 2>/dev/null | wc -l)
log "Backups retained: $BACKUP_COUNT"

# 3. Check container health
log "[3/6] Checking container health..."
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | grep "localai" || true)
if [ -n "$UNHEALTHY" ]; then
    log "ERROR: Unhealthy containers: $UNHEALTHY"
    log "Attempting restart..."
    docker restart $UNHEALTHY
    sleep 10
else
    log "All containers healthy"
fi

# 4. Check disk space
log "[4/6] Checking disk space..."
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log "WARNING: Disk usage is ${DISK_USAGE}% - consider cleanup"

    # Clean Docker cache
    log "Running Docker cleanup..."
    docker system prune -f --volumes
fi

# 5. Database integrity check
log "[5/6] Checking database integrity..."
DB_PATH="${DATA_DIR}/backend/purchases.db"
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" "PRAGMA integrity_check;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        RECORD_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM purchases;" 2>/dev/null || echo "0")
        log "Database OK: $RECORD_COUNT purchases"
    else
        log "ERROR: Database integrity check failed"
    fi
else
    log "WARNING: Database not found (normal for fresh install)"
fi

# 6. Resource monitoring
log "[6/6] Resource snapshot..."
docker stats --no-stream --format "{{.Container}}: CPU {{.CPUPerc}}, Mem {{.MemUsage}}" \
    localai-ollama localai-backend localai-frontend 2>/dev/null | \
    while read line; do log "$line"; done

# Summary
log "=========================================="
log "Backup and monitoring complete"
log "=========================================="

# Send alert if critical errors (optional - requires mail setup)
ERROR_COUNT=$(grep -c "ERROR:" "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$ERROR_COUNT" -gt 0 ]; then
    log "ALERT: $ERROR_COUNT errors detected - manual review required"
    # Uncomment to send email alert:
    # echo "Check log: $LOG_FILE" | mail -s "Local AI Studio Alert" admin@example.com
fi

exit 0
