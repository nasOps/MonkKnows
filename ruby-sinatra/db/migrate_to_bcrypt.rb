# frozen_string_literal: true

# Migration script: adds password_digest column for bcrypt migration
# Run once: ruby db/migrate_to_bcrypt.rb
#
# After migration, existing users keep their MD5 hash in 'password'.
# On next login, passwords are re-hashed with bcrypt into 'password_digest'.

require_relative '../config/environment'

ActiveRecord::Base.connection.execute(<<-SQL)
  ALTER TABLE users ADD COLUMN password_digest TEXT;
SQL

puts 'Migration complete: added password_digest column to users table'
