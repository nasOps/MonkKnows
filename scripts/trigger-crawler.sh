#!/bin/bash
# Manually trigger the MonkKnows crawler Azure Function via HTTP.
#
# Usage:
#   AZURE_CRAWLER_FUNCTION_KEY=<function-key> ./scripts/trigger-crawler.sh
#   (or add AZURE_CRAWLER_FUNCTION_KEY to ruby-sinatra/.env)
#
# The function key is found in Azure Portal:
#   monkknows-crawler > Functions > crawler_http > Function Keys > default

set -euo pipefail

FUNCTION_URL="https://monkknows-crawler.azurewebsites.net/api/crawl"

ENV_FILE="$(dirname "$0")/../ruby-sinatra/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

FUNCTION_KEY="${AZURE_CRAWLER_FUNCTION_KEY:-}"

if [[ -z "$FUNCTION_KEY" ]]; then
  echo "Error: AZURE_CRAWLER_FUNCTION_KEY is not set."
  echo "Add it to ruby-sinatra/.env (see .env-template)"
  exit 1
fi

echo "Triggering crawler..."

ENCODED_KEY=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$FUNCTION_KEY")
response=$(curl -s -w "\n%{http_code}" -X POST "$FUNCTION_URL?code=$ENCODED_KEY")

body=$(echo "$response" | head -n -1)
status=$(echo "$response" | tail -n 1)

echo "Status: $status"
echo "Response: $body"

if [[ "$status" != "200" ]]; then
  echo "Crawler failed with status $status"
  exit 1
fi
