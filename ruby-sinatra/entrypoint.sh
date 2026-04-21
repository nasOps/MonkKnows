#!/bin/sh
echo "Setting up logging database..."
ruby db/create_logging_db.rb

echo "Starting app..."
exec ruby app.rb