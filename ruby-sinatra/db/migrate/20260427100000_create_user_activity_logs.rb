# frozen_string_literal: true

class CreateUserActivityLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :user_activity_logs do |t|
      t.integer :user_id, null: false
      t.string  :path
      t.timestamps
    end

    add_index :user_activity_logs, %i[user_id created_at]
    add_index :user_activity_logs, :created_at
  end
end
