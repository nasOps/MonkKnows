# frozen_string_literal: true

require 'active_record'
require_relative '../models/base/logging_base'

class CreateSearchLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :search_logs do |t|
      t.string :query
      t.string :path
      t.string :method
      t.integer :status
      t.string :ip
      t.float :duration_ms
      t.timestamps
    end
  end
end
