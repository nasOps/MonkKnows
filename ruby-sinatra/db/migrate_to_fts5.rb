# frozen_string_literal: true

# Migration script: creates FTS5 virtual table for full-text search
# Run once: ruby db/migrate_to_fts5.rb
#
# Creates a virtual FTS5 table mirroring pages, plus triggers to keep it in sync.
# After migration, search queries use FTS5 ranking instead of LIKE.

require_relative '../config/environment'

connection = ActiveRecord::Base.connection

# Create FTS5 virtual table with content synced from pages
connection.execute(<<-SQL)
  CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
    title,
    content,
    content='pages',
    content_rowid='rowid'
  );
SQL

# Populate FTS5 table with existing data
connection.execute(<<-SQL)
  INSERT INTO pages_fts(rowid, title, content)
  SELECT rowid, title, content FROM pages;
SQL

# Trigger: keep FTS5 in sync on INSERT
connection.execute(<<-SQL)
  CREATE TRIGGER IF NOT EXISTS pages_ai AFTER INSERT ON pages BEGIN
    INSERT INTO pages_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
  END;
SQL

# Trigger: keep FTS5 in sync on DELETE
connection.execute(<<-SQL)
  CREATE TRIGGER IF NOT EXISTS pages_ad AFTER DELETE ON pages BEGIN
    INSERT INTO pages_fts(pages_fts, rowid, title, content)
    VALUES('delete', old.rowid, old.title, old.content);
  END;
SQL

# Trigger: keep FTS5 in sync on UPDATE
connection.execute(<<-SQL)
  CREATE TRIGGER IF NOT EXISTS pages_au AFTER UPDATE ON pages BEGIN
    INSERT INTO pages_fts(pages_fts, rowid, title, content)
    VALUES('delete', old.rowid, old.title, old.content);
    INSERT INTO pages_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
  END;
SQL

row_count = connection.execute('SELECT count(*) as cnt FROM pages_fts').first['cnt']
puts "Migration complete: FTS5 table created with #{row_count} rows"
