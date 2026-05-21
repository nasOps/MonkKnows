# frozen_string_literal: true

class AddIndexToSearchLogsQuery < ActiveRecord::Migration[7.2]
  def change
    add_index :search_logs, :query
  end
end
