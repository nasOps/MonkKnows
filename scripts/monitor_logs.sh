#!/bin/bash
# Container log monitor — pages Discord on HTTP 4xx/5xx or "Error" strings in app-web-1 logs.
# Runs every 5 min via root cron on VM1:
#   */5 * * * * /usr/local/bin/monitor_logs.sh
#
# Deploy: copy to /usr/local/bin/monitor_logs.sh on VM1, chmod +x, and ensure
# /etc/monkknows/monitor.env (chmod 0600) defines DISCORD_WEBHOOK=https://...
# CD does NOT install this yet — manual deploy. Track in #251 follow-up.

set -u

ENV_FILE="/etc/monkknows/monitor.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

: "${DISCORD_WEBHOOK:?DISCORD_WEBHOOK must be set (see $ENV_FILE)}"

CONTAINER="app-web-1"
LAST_CHECK_FILE="/tmp/last_log_check"
LOG_FILE="/var/log/whoknows_monitor.log"

send_discord() {
  local message=$1
  curl -s -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$message\"}" > /dev/null
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

if [ ! -f "$LAST_CHECK_FILE" ]; then
  date +%s > "$LAST_CHECK_FILE"
fi

LAST_CHECK=$(cat "$LAST_CHECK_FILE")

ERRORS=$(docker logs "$CONTAINER" --since "@${LAST_CHECK}" 2>&1 | grep -E "HTTP [45][0-9][0-9]|Error|error" | tail -20)

if [ -n "$ERRORS" ]; then
  log "ALERT - Fejl fundet i container logs:"
  echo "$ERRORS" >> "$LOG_FILE"

  DISCORD_MESSAGE="⚠️ MonkKnows Monitor Alert\nServer: $(hostname)\nTime: $(date '+%Y-%m-%d %H:%M:%S')\n\`\`\`${ERRORS}\`\`\`"

  send_discord "$DISCORD_MESSAGE"
else
  log "OK - Ingen fejl fundet"
fi

date +%s > "$LAST_CHECK_FILE"
