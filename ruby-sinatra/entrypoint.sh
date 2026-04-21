#!/bin/sh
set -e

echo "Setting up logging database..."
bundle exec ruby db/create_logging_db.rb
exec bundle exec rackup config.ru -p 4567 -o 0.0.0.0
