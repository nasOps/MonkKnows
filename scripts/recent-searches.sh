#!/bin/bash
# Show most recent searches from the MonkKnows database.

LIMIT="${1:-10}"

ssh monkknows-db "docker exec monkknows-db-db-1 psql -U monkknows -d monkknows -c \
  'SELECT query, result_count, created_at FROM search_logs ORDER BY created_at DESC LIMIT $LIMIT;'"
