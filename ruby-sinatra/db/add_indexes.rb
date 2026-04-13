# frozen_string_literal: true

# Migration script: adds database indexes for improved query performance
# Run once: ruby db/add_indexes.rb

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

puts 'Migration complete: added indexes to pages table'
puts ''
puts 'Indexes created:'
connection.execute("SELECT name, tbl_name FROM sqlite_master WHERE type='index' ORDER BY tbl_name").each do |row|
  puts "  #{row['name']} on #{row['tbl_name']}"
end
