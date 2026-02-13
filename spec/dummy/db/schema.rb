# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2024_01_01_000005) do
  create_table "faultline_error_contexts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "error_occurrence_id", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["error_occurrence_id"], name: "index_faultline_error_contexts_on_error_occurrence_id"
  end

  create_table "faultline_error_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exception_class", null: false
    t.string "file_path"
    t.string "fingerprint", null: false
    t.datetime "first_seen_at"
    t.datetime "last_notified_at"
    t.datetime "last_seen_at"
    t.integer "line_number"
    t.string "method_name"
    t.integer "occurrences_count", default: 0
    t.datetime "resolved_at"
    t.string "sanitized_message", null: false
    t.string "status", default: "unresolved"
    t.datetime "updated_at", null: false
    t.index ["exception_class"], name: "index_faultline_error_groups_on_exception_class"
    t.index ["fingerprint"], name: "index_faultline_error_groups_on_fingerprint", unique: true
    t.index ["last_seen_at"], name: "index_faultline_error_groups_on_last_seen_at"
    t.index ["status"], name: "index_faultline_error_groups_on_status"
  end

  create_table "faultline_error_occurrences", force: :cascade do |t|
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.string "environment"
    t.integer "error_group_id", null: false
    t.string "exception_class"
    t.string "hostname"
    t.string "ip_address"
    t.text "local_variables"
    t.text "message"
    t.string "process_id"
    t.text "request_headers"
    t.string "request_method"
    t.text "request_params"
    t.text "request_url"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id"
    t.string "user_type"
    t.index ["created_at"], name: "index_faultline_error_occurrences_on_created_at"
    t.index ["error_group_id"], name: "index_faultline_error_occurrences_on_error_group_id"
  end

  create_table "faultline_request_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "interval_ms"
    t.string "mode", default: "cpu"
    t.text "profile_data", null: false
    t.integer "request_trace_id", null: false
    t.integer "samples", default: 0
    t.index ["request_trace_id"], name: "index_faultline_request_profiles_on_request_trace_id"
  end

  create_table "faultline_request_traces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "db_query_count", default: 0
    t.float "db_runtime_ms"
    t.float "duration_ms"
    t.string "endpoint", null: false
    t.boolean "has_profile", default: false
    t.string "http_method", null: false
    t.string "path"
    t.json "spans"
    t.integer "status"
    t.float "view_runtime_ms"
    t.index ["created_at"], name: "index_faultline_request_traces_on_created_at"
    t.index ["endpoint", "created_at"], name: "index_faultline_request_traces_on_endpoint_and_created_at"
    t.index ["endpoint"], name: "index_faultline_request_traces_on_endpoint"
  end

  add_foreign_key "faultline_error_contexts", "faultline_error_occurrences", column: "error_occurrence_id"
  add_foreign_key "faultline_error_occurrences", "faultline_error_groups", column: "error_group_id"
  add_foreign_key "faultline_request_profiles", "faultline_request_traces", column: "request_trace_id", on_delete: :cascade
end
