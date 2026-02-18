# frozen_string_literal: true

class CreateFaultlineErrorGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :faultline_error_groups do |t|
      t.string :fingerprint, null: false
      t.string :exception_class, null: false
      t.string :sanitized_message, null: false
      t.string :file_path
      t.integer :line_number
      t.string :method_name

      t.integer :occurrences_count, default: 0
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.string :status, default: "unresolved"
      t.datetime :resolved_at
      t.datetime :last_notified_at

      t.timestamps
    end

    add_index :faultline_error_groups, :fingerprint, unique: true
    add_index :faultline_error_groups, :exception_class
    add_index :faultline_error_groups, :status
    add_index :faultline_error_groups, :last_seen_at
  end
end
