#!/bin/bash
# Blue-Green Cutover: SQLite → PostgreSQL
#
# Automated production cutover with rollback capability.
# Run from a machine that can SSH to both VM1 (monkknows) and VM2 (monkknows-db).
#
# Usage:
#   bash scripts/cutover_to_pg.sh
#
# Prerequisites:
#   - SSH config with 'monkknows' (VM1) and 'monkknows-db' (VM2) hosts
#   - Data already migrated via scripts/migrate_sqlite_to_pg.rb
#   - New Docker image with pg gem already pushed to GHCR

set -euo pipefail

# --- Configuration ---
VM1_HOST="monkknows"
VM2_HOST="monkknows-db"
VM2_IP="20.91.203.235"
APP_DIR="/opt/whoknows/app"
PROD_URL="https://monkknows.dk"
DB_NAME="monkknows"
DB_USER="monkknows"
DB_PASS_FILE="/opt/monkknows-db/db_password.txt"

log() { echo "[$(date '+%H:%M:%S')] $1"; }
fail() { log "FAILED: $1"; exit 1; }

cleanup_temp_access() {
  log "Cleaning up temporary firewall access..."
  ssh "$VM2_HOST" "sed -i '/${LOCAL_IP}/d' /opt/monkknows-db/pg_hba.conf && cd /opt/monkknows-db && sg docker -c 'docker compose restart db'" 2>/dev/null || true
  az network nsg rule delete \
    --resource-group PRIVATEPROJECT_GROUP \
    --nsg-name PrivateProject-nsg \
    --name TempCutoverAccess \
    --output none 2>/dev/null || true
}

# --- Phase 1: Pre-flight checks ---
log "=== Phase 1: Pre-flight checks ==="

log "Checking VM2 PostgreSQL..."
ssh "$VM2_HOST" "sg docker -c 'docker compose -f /opt/monkknows-db/docker-compose.yml ps'" | grep -q healthy \
  || fail "PostgreSQL on VM2 is not healthy"
log "PostgreSQL is healthy."

log "Checking current app status..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -L "$PROD_URL/health")
[ "$HTTP_STATUS" -eq 200 ] || fail "App is not healthy (status: $HTTP_STATUS)"
log "App is healthy (status: $HTTP_STATUS)."

log "Reading DB password..."
DB_PASS=$(ssh "$VM2_HOST" "cat $DB_PASS_FILE")
[ -n "$DB_PASS" ] || fail "Could not read DB password"
log "Password retrieved."

# --- Phase 2: Final delta-sync ---
log "=== Phase 2: Final delta-sync ==="

log "Copying latest SQLite from VM1..."
scp "$VM1_HOST:/opt/whoknows/data/whoknows.db" /tmp/whoknows_cutover.db

log "Opening temporary firewall for migration..."
LOCAL_IP=$(curl -s ifconfig.me)
trap cleanup_temp_access EXIT
az network nsg rule create \
  --resource-group PRIVATEPROJECT_GROUP \
  --nsg-name PrivateProject-nsg \
  --name TempCutoverAccess \
  --priority 320 \
  --direction Inbound \
  --access Allow \
  --protocol TCP \
  --destination-port-ranges 5432 \
  --source-address-prefixes "$LOCAL_IP" \
  --output none 2>/dev/null

# Temporarily allow local IP in pg_hba.conf
ssh "$VM2_HOST" "sed -i '/# Reject everything else/i host    all       monkknows  ${LOCAL_IP}/32 md5' /opt/monkknows-db/pg_hba.conf && cd /opt/monkknows-db && sg docker -c 'docker compose restart db'" 2>/dev/null
sleep 3

log "Running delta-sync..."
DB_HOST="$VM2_IP" DB_USER="$DB_USER" DB_PASSWORD="$DB_PASS" DB_NAME="$DB_NAME" \
  ruby scripts/migrate_sqlite_to_pg.rb /tmp/whoknows_cutover.db

log "Delta-sync complete."

# --- Phase 3: Cutover ---
log "=== Phase 3: Cutover ==="

log "Backing up current .env on VM1..."
ssh "$VM1_HOST" "cp $APP_DIR/.env $APP_DIR/.env.sqlite.backup"

log "Updating .env with PostgreSQL credentials..."
DB_HOST_VAL="$VM2_IP" DB_USER_VAL="$DB_USER" DB_PASS_VAL="$DB_PASS" DB_NAME_VAL="$DB_NAME" \
  ssh "$VM1_HOST" 'bash -s' <<'REMOTE'
SESSION_SECRET=$(grep SESSION_SECRET "$APP_DIR/.env.sqlite.backup" | cut -d= -f2-)
OPENWEATHER_API_KEY=$(grep OPENWEATHER_API_KEY "$APP_DIR/.env.sqlite.backup" | cut -d= -f2-)
cat > "$APP_DIR/.env" <<EOF
SESSION_SECRET=$SESSION_SECRET
OPENWEATHER_API_KEY=$OPENWEATHER_API_KEY
DB_HOST=$DB_HOST_VAL
DB_USER=$DB_USER_VAL
DB_PASSWORD=$DB_PASS_VAL
DB_NAME=$DB_NAME_VAL
EOF
REMOTE

log "Deploying with PostgreSQL..."
ssh "$VM1_HOST" "cd $APP_DIR && docker compose -f docker-compose.prod.yml pull && docker compose -f docker-compose.prod.yml up -d --remove-orphans"

log "Waiting for app to start..."
sleep 10

# --- Phase 4: Verify ---
log "=== Phase 4: Smoke tests ==="

HEALTH=$(curl -o /dev/null -s -w "%{http_code}" -L "$PROD_URL/health")
log "GET /health: $HEALTH"

SEARCH=$(curl -o /dev/null -s -w "%{http_code}" -L "$PROD_URL/api/search?q=test&language=en")
log "GET /api/search?q=test: $SEARCH"

LOGIN=$(curl -o /dev/null -s -w "%{http_code}" -X POST "$PROD_URL/api/login" \
  -H "Content-Type: application/json" -d '{"username":"nonexistent","password":"x"}')
log "POST /api/login (invalid): $LOGIN"

if [ "$HEALTH" -eq 200 ] && [ "$SEARCH" -eq 200 ] && [ "$LOGIN" -eq 422 ]; then
  log "=== ALL SMOKE TESTS PASSED ==="
  log "Cutover complete. App is running on PostgreSQL."
  log ""
  log "SQLite backup preserved at: $APP_DIR/.env.sqlite.backup"
  log "SQLite file preserved at: /opt/whoknows/data/whoknows.db"
  log ""
  log "To rollback: bash scripts/rollback_to_sqlite.sh"
else
  log "=== SMOKE TESTS FAILED — ROLLING BACK ==="
  ssh "$VM1_HOST" "cp $APP_DIR/.env.sqlite.backup $APP_DIR/.env && cd $APP_DIR && docker compose -f docker-compose.prod.yml up -d --remove-orphans"
  sleep 10
  ROLLBACK_CHECK=$(curl -o /dev/null -s -w "%{http_code}" -L "$PROD_URL/health")
  log "Rollback health check: $ROLLBACK_CHECK"
  fail "Cutover failed. Rolled back to SQLite."
fi
