# frozen_string_literal: true

class AddResultCountToSearchLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :search_logs, :result_count, :integer
  end
end
