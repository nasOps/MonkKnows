#!/bin/bash
# PostgreSQL backup script — runs daily via cron
# 1. Dumps to VM2 (local)
# 2. Copies to VM1 (offsite)
# Keeps last 7 days on both servers
#
# Deploy: copy to /opt/monkknows-db/backup.sh on VM2 and add to root crontab:
#   0 3 * * * /opt/monkknows-db/backup.sh >> /opt/monkknows-db/backups/backup.log 2>&1

set -euo pipefail

BACKUP_DIR=/opt/monkknows-db/backups
CONTAINER=monkknows-db-db-1
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
BACKUP_FILE="$BACKUP_DIR/monkknows_$TIMESTAMP.sql.gz"
KEEP_DAYS=7
VM1_HOST=adminuser@4.225.161.111
VM1_BACKUP_DIR=/opt/whoknows/backups

echo "[$TIMESTAMP] Starting backup..."

# Dump and compress
docker exec $CONTAINER pg_dump -U monkknows monkknows | gzip > "$BACKUP_FILE"

# Verify backup is not empty
if [ ! -s "$BACKUP_FILE" ]; then
  echo "[$TIMESTAMP] ERROR: Backup file is empty!"
  rm -f "$BACKUP_FILE"
  exit 1
fi

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$TIMESTAMP] Backup complete: $BACKUP_FILE ($SIZE)"

# Copy to VM1
ssh -o StrictHostKeyChecking=no $VM1_HOST "mkdir -p $VM1_BACKUP_DIR" 2>/dev/null
if scp -o StrictHostKeyChecking=no "$BACKUP_FILE" "$VM1_HOST:$VM1_BACKUP_DIR/"; then
  echo "[$TIMESTAMP] Copied to VM1"
  # Clean old backups on VM1
  ssh $VM1_HOST "find $VM1_BACKUP_DIR -name 'monkknows_*.sql.gz' -mtime +$KEEP_DAYS -delete" 2>/dev/null
else
  echo "[$TIMESTAMP] WARNING: Failed to copy to VM1"
fi

# Clean old backups on VM2
find $BACKUP_DIR -name 'monkknows_*.sql.gz' -mtime +$KEEP_DAYS -delete
echo "[$TIMESTAMP] Cleanup done. Keeping last $KEEP_DAYS days."
