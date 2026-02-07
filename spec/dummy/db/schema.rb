# frozen_string_literal: true

ActiveRecord::Schema[8.0].define(version: 2024_01_01_000005) do
  create_table "faultline_error_groups", force: :cascade do |t|
    t.string "fingerprint", null: false
    t.string "exception_class", null: false
    t.string "sanitized_message", null: false
    t.string "file_path"
    t.integer "line_number"
    t.string "method_name"
    t.integer "occurrences_count", default: 0
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.string "status", default: "unresolved"
    t.datetime "resolved_at"
    t.datetime "last_notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exception_class"], name: "index_faultline_error_groups_on_exception_class"
    t.index ["fingerprint"], name: "index_faultline_error_groups_on_fingerprint", unique: true
    t.index ["last_seen_at"], name: "index_faultline_error_groups_on_last_seen_at"
    t.index ["status"], name: "index_faultline_error_groups_on_status"
  end

  create_table "faultline_error_occurrences", force: :cascade do |t|
    t.integer "error_group_id", null: false
    t.string "exception_class"
    t.text "message"
    t.text "backtrace"
    t.text "local_variables"
    t.integer "user_id"
    t.string "user_type"
    t.string "environment"
    t.string "hostname"
    t.string "process_id"
    t.string "request_method"
    t.text "request_url"
    t.text "request_params"
    t.text "request_headers"
    t.string "user_agent"
    t.string "ip_address"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_faultline_error_occurrences_on_created_at"
    t.index ["error_group_id"], name: "index_faultline_error_occurrences_on_error_group_id"
  end

  create_table "faultline_error_contexts", force: :cascade do |t|
    t.integer "error_occurrence_id", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["error_occurrence_id"], name: "index_faultline_error_contexts_on_error_occurrence_id"
  end

  create_table "faultline_request_traces", force: :cascade do |t|
    t.string "endpoint", null: false
    t.string "http_method", null: false
    t.string "path"
    t.integer "status"
    t.float "duration_ms"
    t.float "db_runtime_ms"
    t.float "view_runtime_ms"
    t.integer "db_query_count", default: 0
    t.json "spans"
    t.boolean "has_profile", default: false
    t.datetime "created_at", null: false
    t.index ["endpoint"], name: "index_faultline_request_traces_on_endpoint"
    t.index ["created_at"], name: "index_faultline_request_traces_on_created_at"
    t.index ["endpoint", "created_at"], name: "index_faultline_request_traces_on_endpoint_and_created_at"
  end

  create_table "faultline_request_profiles", force: :cascade do |t|
    t.integer "request_trace_id", null: false
    t.text "profile_data", null: false
    t.string "mode", default: "cpu"
    t.integer "samples", default: 0
    t.float "interval_ms"
    t.datetime "created_at", null: false
    t.index ["request_trace_id"], name: "index_faultline_request_profiles_on_request_trace_id"
  end

  add_foreign_key "faultline_error_occurrences", "faultline_error_groups", column: "error_group_id"
  add_foreign_key "faultline_error_contexts", "faultline_error_occurrences", column: "error_occurrence_id"
  add_foreign_key "faultline_request_profiles", "faultline_request_traces", column: "request_trace_id", on_delete: :cascade
end
