# frozen_string_literal: true

# Flags ALL users for forced password reset after security breach.
# Run once: ruby db/flag_all_users_for_reset.rb
#
# Requires fix_password_not_null.rb to have been run first.

require_relative '../config/environment'

connection = ActiveRecord::Base.connection

connection.execute('UPDATE users SET force_password_reset = 1')
count = connection.execute('SELECT count(*) as c FROM users WHERE force_password_reset = 1').first['c']
puts "Flagged #{count} users for forced password reset"
