#!/bin/sh
set -e

echo "Running migrations..."
bundle exec rake db:migrate

exec bundle exec rackup config.ru -p 4567 -o 0.0.0.0
