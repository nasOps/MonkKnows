#!/bin/bash
# Rollback: PostgreSQL → SQLite
#
# Restores the app to use SQLite if the PostgreSQL cutover caused issues.
#
# Usage:
#   bash scripts/rollback_to_sqlite.sh

set -euo pipefail

VM1_HOST="monkknows"
APP_DIR="/opt/whoknows/app"
PROD_URL="https://monkknows.dk"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "=== Rolling back to SQLite ==="

log "Restoring .env backup..."
ssh "$VM1_HOST" "cp $APP_DIR/.env.sqlite.backup $APP_DIR/.env"

log "Restarting app..."
ssh "$VM1_HOST" "cd $APP_DIR && docker compose -f docker-compose.prod.yml up -d --remove-orphans"

log "Waiting for app to start..."
sleep 10

HEALTH=$(curl -o /dev/null -s -w "%{http_code}" -L "$PROD_URL/health" || echo "000")
log "Health check: $HEALTH"

if [ "$HEALTH" = "200" ]; then
  log "Rollback successful. App is running on SQLite."
else
  log "WARNING: App may not be healthy after rollback (status: $HEALTH)"
fi
