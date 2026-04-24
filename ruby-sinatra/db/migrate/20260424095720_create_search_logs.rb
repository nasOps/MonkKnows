# frozen_string_literal: true

class CreateSearchLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :search_logs do |t|
      t.string  :query
      t.string  :path
      t.string  :http_method
      t.integer :status
      t.string  :ip
      t.float   :duration_ms
      t.timestamps
    end

    add_index :search_logs, :created_at
  end
end
