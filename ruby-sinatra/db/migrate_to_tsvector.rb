# frozen_string_literal: true

# Migration: FTS5 → PostgreSQL tsvector
# Replaces SQLite's pages_fts virtual table with native PostgreSQL full-text search.
#
# Run: ruby db/migrate_to_tsvector.rb
#
# What it does:
# 1. Adds a tsvector column (tsv) to the pages table
# 2. Populates it from existing title + content
# 3. Creates a GIN index for fast full-text search
# 4. Creates a trigger to auto-update tsv on INSERT/UPDATE

require_relative '../config/environment'

unless ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  puts 'This migration is only for PostgreSQL. Skipping.'
  exit 0
end

conn = ActiveRecord::Base.connection

puts 'Adding tsvector column to pages...'
conn.execute('ALTER TABLE pages ADD COLUMN tsv tsvector') unless conn.column_exists?(:pages, :tsv)

puts 'Populating tsvector from existing data...'
conn.execute(<<-SQL)
  UPDATE pages SET tsv = to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))
  WHERE tsv IS NULL
SQL

puts 'Creating GIN index on tsvector column...'
unless conn.index_exists?(:pages, :tsv, name: 'idx_pages_tsv')
  conn.execute('CREATE INDEX idx_pages_tsv ON pages USING GIN(tsv)')
end

puts 'Creating auto-update trigger...'
conn.execute(<<-SQL)
  CREATE OR REPLACE FUNCTION pages_tsv_update_trigger() RETURNS trigger AS $$
  BEGIN
    NEW.tsv := to_tsvector('english', coalesce(NEW.title, '') || ' ' || coalesce(NEW.content, ''));
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
SQL

conn.execute(<<-SQL)
  DROP TRIGGER IF EXISTS pages_tsv_update ON pages;
  CREATE TRIGGER pages_tsv_update
    BEFORE INSERT OR UPDATE ON pages
    FOR EACH ROW EXECUTE FUNCTION pages_tsv_update_trigger();
SQL

puts 'FTS5 → tsvector migration complete.'
