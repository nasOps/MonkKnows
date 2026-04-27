# frozen_string_literal: true

class CreateExceptionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :exception_logs do |t|
      t.string :path
      t.string :http_method
      t.string :error_class
      t.text   :error_message
      t.string :first_frame
      t.timestamps
    end

    add_index :exception_logs, :created_at
    add_index :exception_logs, :error_class
  end
end
