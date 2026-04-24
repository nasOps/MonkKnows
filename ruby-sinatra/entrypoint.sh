#!/bin/sh
set -e

echo "Waiting for database..."

until bundle exec ruby -e "
require 'pg';
begin
  PG.connect(
    host: ENV['DB_HOST'],
    user: ENV['DB_USER'],
    password: ENV['DB_PASSWORD'],
    dbname: ENV['DB_NAME']
  ).close
rescue
  exit 1
end
"
do
  echo "DB not ready, retrying..."
  sleep 2
done

echo "Database is ready!"

echo "Running migrations..."
bundle exec rake db:migrate

echo "Running data migration (safe)..."
bundle exec rake data:migrate_logs || true

exec bundle exec rackup config.ru -p 4567 -o 0.0.0.0
