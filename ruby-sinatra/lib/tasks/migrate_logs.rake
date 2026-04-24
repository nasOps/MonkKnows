# frozen_string_literal: true

# Migrates SQLite DB to PostgreSQL, then backs up the SQLite file by renaming it to logging.sqlite3.bak

namespace :data do
  desc 'Migrate SQLite logs to PostgreSQL'
  task migrate_logs: :environment do
    require 'sqlite3'
    '
'
    # Determine the path to the SQLite file based on the environment
    sqlite_path =
      if ENV['RACK_ENV'] == 'production'
        '/app/db/logging/logging.sqlite3'
      else
        'db/logging/logging.sqlite3'
      end

    # Check if the SQLite file exists before attempting to migrate
    unless File.exist?(sqlite_path)
      puts "No SQLite file found at #{sqlite_path}"
      next
    end

    # Check if there are already logs in the PostgreSQL database to avoid duplicates
    if SearchLog.exists?
      puts 'Already migrated — skipping'
      next
    end

    # Connect to the SQLite database and read the logs
    sqlite = SQLite3::Database.new(sqlite_path)
    sqlite.results_as_hash = true

    # Fetch all rows from the search_logs table in SQLite
    rows = sqlite.execute('SELECT * FROM search_logs')

    puts "Found #{rows.count} rows"

    # Migrate each row to the PostgreSQL database using ActiveRecord
    rows.each do |row|
      SearchLog.create(
        query: row['query'],
        path: row['path'],
        http_method: row['http_method'],
        status: row['status'],
        ip: row['ip'],
        duration_ms: row['duration_ms'],
        created_at: row['created_at'],
        updated_at: row['created_at']
      )
    end

    puts "Migrated #{rows.count} rows"

    # Backup the SQLite file after migration, moving logging.sqlite3 → logging.sqlite3.bak
    File.rename(sqlite_path, "#{sqlite_path}.bak")
    puts 'SQLite backed up'
  end
end
