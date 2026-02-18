# frozen_string_literal: true

class CreateFaultlineErrorOccurrencesAndContexts < ActiveRecord::Migration[8.1]
  def change
    create_table :faultline_error_occurrences do |t|
      t.integer :error_group_id, null: false
      t.string :exception_class
      t.text :message
      t.text :backtrace
      t.text :local_variables

      t.string :request_method
      t.text :request_url
      t.text :request_params
      t.text :request_headers
      t.string :user_agent
      t.string :ip_address
      t.string :session_id

      t.integer :user_id
      t.string :user_type

      t.string :environment
      t.string :hostname
      t.string :process_id

      t.timestamps
    end

    add_index :faultline_error_occurrences, :error_group_id
    add_index :faultline_error_occurrences, :created_at
    add_foreign_key :faultline_error_occurrences, :faultline_error_groups,
                    column: :error_group_id

    create_table :faultline_error_contexts do |t|
      t.integer :error_occurrence_id, null: false
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :faultline_error_contexts, :error_occurrence_id
    add_foreign_key :faultline_error_contexts, :faultline_error_occurrences,
                    column: :error_occurrence_id
  end
end
