# frozen_string_literal: true

# Migration script: adds database indexes for improved query performance
# Safe to re-run (idempotent): ruby db/add_indexes.rb

require_relative '../config/environment'

connection = ActiveRecord::Base.connection

# Index on pages.language — used in every search query (WHERE language = ?)
connection.execute(<<-SQL)
  CREATE INDEX IF NOT EXISTS idx_pages_language ON pages(language);
SQL

# Index on pages.url — used for lookups by URL
connection.execute(<<-SQL)
  CREATE INDEX IF NOT EXISTS idx_pages_url ON pages(url);
SQL

# Index on pages.last_updated — useful for ordering results by recency
connection.execute(<<-SQL)
  CREATE INDEX IF NOT EXISTS idx_pages_last_updated ON pages(last_updated);
SQL

expected = %w[idx_pages_language idx_pages_url idx_pages_last_updated]
existing = connection.execute(
  "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='pages'"
).map { |r| r['name'] }

missing = expected - existing
raise "Index verification failed — missing: #{missing.join(', ')}" unless missing.empty?

puts 'Migration complete: added and verified indexes on pages table'
expected.each { |name| puts "  ✓ #{name}" }
