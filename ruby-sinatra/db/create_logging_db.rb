# frozen_string_literal: true

require_relative '../config/environment'
require_relative '../models/base/logging_base'

if LoggingBase.connection.table_exists?(:search_logs)
  puts 'search_logs already exists'
else
  LoggingBase.connection.create_table :search_logs do |t|
    t.string :query
    t.string :path
    t.string :http_method
    t.integer :status
    t.string :ip
    t.float :duration_ms
    t.timestamps
  end

  LoggingBase.connection.add_index :search_logs, :created_at

  puts 'Created search_logs table'
end
