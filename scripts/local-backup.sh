#!/bin/bash
# Weekly local backup — pulls latest PG backup from VM2 to local machine
# Runs every Wednesday at 19:00 Danish time via cron
# Keeps last 4 weekly backups locally

set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/backups"
VM2_HOST=monkknows-db
VM2_BACKUP_DIR=/opt/monkknows-db/backups
KEEP_COUNT=4
TIMESTAMP=$(date +%Y-%m-%d)

mkdir -p "$BACKUP_DIR"

echo "[$TIMESTAMP] Pulling latest backup from VM2..."

# Find the newest backup on VM2
LATEST=$(ssh $VM2_HOST "ls -t $VM2_BACKUP_DIR/monkknows_*.sql.gz 2>/dev/null | head -1")

if [ -z "$LATEST" ]; then
  echo "[$TIMESTAMP] ERROR: No backups found on VM2"
  exit 1
fi

FILENAME=$(basename "$LATEST")
LOCAL_FILE="$BACKUP_DIR/$FILENAME"

if [ -f "$LOCAL_FILE" ]; then
  echo "[$TIMESTAMP] Already have $FILENAME — skipping"
  exit 0
fi

scp "$VM2_HOST:$LATEST" "$LOCAL_FILE"
SIZE=$(du -h "$LOCAL_FILE" | cut -f1)
echo "[$TIMESTAMP] Downloaded: $FILENAME ($SIZE)"

# Keep only last KEEP_COUNT backups locally
cd "$BACKUP_DIR"
ls -t monkknows_*.sql.gz 2>/dev/null | tail -n +$((KEEP_COUNT + 1)) | xargs rm -f 2>/dev/null || true
echo "[$TIMESTAMP] Local backup complete. Keeping last $KEEP_COUNT backups."
