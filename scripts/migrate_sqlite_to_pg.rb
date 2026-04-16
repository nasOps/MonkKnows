# frozen_string_literal: true

# SQLite → PostgreSQL Data Migration Script
#
# Migrates all data from the SQLite production database to PostgreSQL.
# Supports delta-sync: can be run multiple times safely (only inserts new rows).
#
# Usage:
#   1. Copy whoknows.db from VM1:
#      scp monkknows:/opt/whoknows/data/whoknows.db /tmp/whoknows.db
#
#   2. Run with PostgreSQL credentials:
#      DB_HOST=20.91.203.235 DB_USER=monkknows DB_PASSWORD=<pass> DB_NAME=monkknows \
#        ruby scripts/migrate_sqlite_to_pg.rb /tmp/whoknows.db

require 'sqlite3'
require 'pg'

SQLITE_PATH = ARGV[0] || '/tmp/whoknows.db'

# PostgreSQL connection from environment
PG_CONFIG = {
  host: ENV.fetch('DB_HOST'),
  dbname: ENV.fetch('DB_NAME', 'monkknows'),
  user: ENV.fetch('DB_USER'),
  password: ENV.fetch('DB_PASSWORD')
}.freeze

def connect_sqlite
  db = SQLite3::Database.new(SQLITE_PATH)
  db.results_as_hash = true
  db
end

def connect_pg
  PG.connect(PG_CONFIG)
end

def create_pg_schema(pg)
  puts '--- Creating PostgreSQL schema ---'

  pg.exec(<<-SQL)
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password TEXT,
      password_digest TEXT,
      force_password_reset INTEGER DEFAULT 0
    );
  SQL

  pg.exec(<<-SQL)
    CREATE TABLE IF NOT EXISTS pages (
      title TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      language TEXT NOT NULL DEFAULT 'en',
      last_updated TIMESTAMP,
      content TEXT NOT NULL
    );
  SQL

  puts 'Schema created.'
end

def migrate_users(sqlite, pg)
  puts "\n--- Migrating users ---"

  # Find last migrated user ID for delta-sync
  result = pg.exec('SELECT COALESCE(MAX(id), 0) AS max_id FROM users')
  last_id = result[0]['max_id'].to_i
  puts "Last migrated user ID: #{last_id}"

  users = sqlite.execute('SELECT * FROM users WHERE id > ? ORDER BY id', [last_id])
  puts "New users to migrate: #{users.length}"

  return if users.empty?

  pg.prepare('insert_user', <<-SQL)
    INSERT INTO users (id, username, email, password, password_digest, force_password_reset)
    VALUES ($1, $2, $3, $4, $5, $6)
    ON CONFLICT (id) DO NOTHING
  SQL

  migrated = 0
  skipped = 0

  users.each do |user|
    # SQLite prod may not have force_password_reset column
    force_reset = user['force_password_reset'] || 0

    begin
      pg.exec_prepared('insert_user', [
        user['id'],
        user['username'],
        user['email'],
        user['password'],
        user['password_digest'],
        force_reset
      ])
      migrated += 1
    rescue PG::UniqueViolation
      skipped += 1
    end
  end

  # Reset sequence to max ID so new inserts get correct IDs
  pg.exec("SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 1) FROM users))")

  puts "Migrated: #{migrated}, Skipped (duplicate): #{skipped}"
end

def migrate_pages(sqlite, pg)
  puts "\n--- Migrating pages ---"

  existing = pg.exec('SELECT COUNT(*) AS cnt FROM pages')[0]['cnt'].to_i
  pages = sqlite.execute('SELECT * FROM pages')
  puts "Pages in SQLite: #{pages.length}, already in PostgreSQL: #{existing}"

  pg.prepare('insert_page', <<-SQL)
    INSERT INTO pages (title, url, language, last_updated, content)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (title) DO UPDATE SET
      url = EXCLUDED.url,
      language = EXCLUDED.language,
      last_updated = EXCLUDED.last_updated,
      content = EXCLUDED.content
  SQL

  pages.each do |page|
    pg.exec_prepared('insert_page', [
      page['title'],
      page['url'],
      page['language'],
      page['last_updated'],
      page['content']
    ])
  end

  puts "Pages migrated: #{pages.length}"
end

def setup_tsvector(pg)
  puts "\n--- Setting up tsvector ---"

  # Add column if not exists
  result = pg.exec(<<-SQL)
    SELECT column_name FROM information_schema.columns
    WHERE table_name = 'pages' AND column_name = 'tsv'
  SQL

  if result.ntuples.zero?
    pg.exec('ALTER TABLE pages ADD COLUMN tsv tsvector')
    puts 'Added tsv column.'
  end

  # Populate tsvector
  pg.exec(<<-SQL)
    UPDATE pages SET tsv = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
  SQL
  puts 'Populated tsvector from title + content.'

  # GIN index
  pg.exec(<<-SQL)
    CREATE INDEX IF NOT EXISTS idx_pages_tsv ON pages USING GIN(tsv)
  SQL
  puts 'GIN index created.'

  # Auto-update trigger
  pg.exec(<<-SQL)
    CREATE OR REPLACE FUNCTION pages_tsv_update_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.tsv := to_tsvector('english', coalesce(NEW.title, '') || ' ' || coalesce(NEW.content, ''));
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
  SQL

  pg.exec(<<-SQL)
    DROP TRIGGER IF EXISTS pages_tsv_update ON pages;
    CREATE TRIGGER pages_tsv_update
      BEFORE INSERT OR UPDATE ON pages
      FOR EACH ROW EXECUTE FUNCTION pages_tsv_update_trigger();
  SQL
  puts 'Auto-update trigger created.'
end

def verify(sqlite, pg)
  puts "\n--- Verification ---"

  sqlite_users = sqlite.execute('SELECT COUNT(*) FROM users')[0][0]
  sqlite_pages = sqlite.execute('SELECT COUNT(*) FROM pages')[0][0]
  pg_users = pg.exec('SELECT COUNT(*) AS cnt FROM users')[0]['cnt'].to_i
  pg_pages = pg.exec('SELECT COUNT(*) AS cnt FROM pages')[0]['cnt'].to_i

  puts "Users — SQLite: #{sqlite_users}, PostgreSQL: #{pg_users}"
  puts "Pages — SQLite: #{sqlite_pages}, PostgreSQL: #{pg_pages}"

  if sqlite_users == pg_users && sqlite_pages == pg_pages
    puts 'Row counts match.'
  else
    puts 'WARNING: Row counts do not match!'
  end
end

# --- Main ---
puts "SQLite → PostgreSQL Migration"
puts "Source: #{SQLITE_PATH}"
puts "Target: #{PG_CONFIG[:host]}/#{PG_CONFIG[:dbname]}"
puts

sqlite = connect_sqlite
pg = connect_pg

create_pg_schema(pg)
migrate_users(sqlite, pg)
migrate_pages(sqlite, pg)
setup_tsvector(pg)
verify(sqlite, pg)

pg.close
sqlite.close

puts "\nMigration complete."
