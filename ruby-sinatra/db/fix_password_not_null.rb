# frozen_string_literal: true

# Migration script: removes NOT NULL constraint from password column
# and adds force_password_reset column for security breach handling.
# Run once: ruby db/fix_password_not_null.rb
#
# SQLite cannot ALTER COLUMN, so we recreate the table.
# Handles both pre- and post-bcrypt migration states.

require_relative '../config/environment'

connection = ActiveRecord::Base.connection

# Detect if password_digest column exists
columns = connection.execute("PRAGMA table_info(users)").map { |c| c['name'] }
has_digest = columns.include?('password_digest')

connection.transaction do
  connection.execute(<<-SQL)
    CREATE TABLE users_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password TEXT,
      password_digest TEXT,
      force_password_reset INTEGER DEFAULT 0
    );
  SQL

  if has_digest
    connection.execute(<<-SQL)
      INSERT INTO users_new (id, username, email, password, password_digest)
      SELECT id, username, email, password, password_digest FROM users;
    SQL
  else
    connection.execute(<<-SQL)
      INSERT INTO users_new (id, username, email, password)
      SELECT id, username, email, password FROM users;
    SQL
  end

  connection.execute('DROP TABLE users;')
  connection.execute('ALTER TABLE users_new RENAME TO users;')
end

puts 'Migration complete:'
puts '  - Removed NOT NULL constraint from password column'
puts '  - Added force_password_reset column'
puts "  - password_digest column: #{has_digest ? 'preserved' : 'added'}"

count = connection.execute('SELECT count(*) as c FROM users').first['c']
puts "  - #{count} users preserved"
