#!/bin/bash
# Show top search terms from the MonkKnows database.

LIMIT="${1:-10}"

ssh monkknows-db "docker exec monkknows-db-db-1 psql -U monkknows -d monkknows -c \
  'SELECT query, COUNT(*) AS count FROM search_logs GROUP BY query ORDER BY count DESC LIMIT $LIMIT;'"
