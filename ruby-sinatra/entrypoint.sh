#!/bin/sh
set -e

echo "Running migrations..."
bundle exec rake db:migrate

echo "Running data migration (safe)..."
bundle exec rake data:migrate_logs || true

exec bundle exec rackup config.ru -p 4567 -o 0.0.0.0
