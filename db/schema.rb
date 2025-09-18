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

ActiveRecord::Schema[8.0].define(version: 2025_09_18_153359) do
  create_table "conversation_states", force: :cascade do |t|
    t.string "line_user_id"
    t.text "state_data"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["line_user_id"], name: "index_conversation_states_on_line_user_id"
  end

  create_table "email_verification_codes", force: :cascade do |t|
    t.string "email", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_email_verification_codes_on_code"
    t.index ["email"], name: "index_email_verification_codes_on_email"
    t.index ["expires_at"], name: "index_email_verification_codes_on_expires_at"
  end

  create_table "employee_line_accounts", force: :cascade do |t|
    t.integer "employee_id", null: false
    t.string "line_user_id", null: false
    t.string "group_id"
    t.datetime "linked_at", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "is_active"], name: "index_employee_line_accounts_on_employee_id_and_is_active"
    t.index ["employee_id"], name: "index_employee_line_accounts_on_employee_id"
    t.index ["group_id"], name: "index_employee_line_accounts_on_group_id"
    t.index ["line_user_id"], name: "index_employee_line_accounts_on_line_user_id", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_id"
    t.string "password_hash"
    t.string "role"
    t.datetime "last_login_at"
    t.datetime "password_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "line_id"
    t.index ["employee_id"], name: "index_employees_on_employee_id", unique: true
    t.index ["line_id"], name: "index_employees_on_line_id", unique: true
  end

  create_table "line_message_logs", force: :cascade do |t|
    t.string "line_user_id", null: false
    t.string "message_type", null: false
    t.text "message_content"
    t.string "direction", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["direction"], name: "index_line_message_logs_on_direction"
    t.index ["line_user_id"], name: "index_line_message_logs_on_line_user_id"
    t.index ["processed_at"], name: "index_line_message_logs_on_processed_at"
  end

  create_table "shift_absences", force: :cascade do |t|
    t.string "request_id", null: false
    t.string "requester_id", null: false
    t.integer "shift_id", null: false
    t.string "status", default: "pending", null: false
    t.text "reason"
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_shift_absences_on_request_id", unique: true
    t.index ["requester_id"], name: "index_shift_absences_on_requester_id"
    t.index ["shift_id"], name: "index_shift_absences_on_shift_id"
    t.index ["status"], name: "index_shift_absences_on_status"
  end

  create_table "shift_additions", force: :cascade do |t|
    t.string "request_id", null: false
    t.string "target_employee_id", null: false
    t.date "shift_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.string "status", default: "pending"
    t.datetime "requested_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "responded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "requester_id", default: "3313254", null: false
    t.index ["request_id"], name: "index_shift_additions_on_request_id", unique: true
    t.index ["requester_id"], name: "index_shift_additions_on_requester_id"
    t.index ["status"], name: "index_shift_additions_on_status"
    t.index ["target_employee_id"], name: "index_shift_additions_on_target_employee_id"
  end

  create_table "shift_deletions", force: :cascade do |t|
    t.string "request_id", null: false
    t.string "requester_id", null: false
    t.integer "shift_id", null: false
    t.text "reason", null: false
    t.string "status", default: "pending", null: false
    t.datetime "requested_at"
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_shift_deletions_on_request_id", unique: true
    t.index ["requester_id"], name: "index_shift_deletions_on_requester_id"
    t.index ["shift_id"], name: "index_shift_deletions_on_shift_id"
    t.index ["status"], name: "index_shift_deletions_on_status"
  end

  create_table "shift_exchanges", force: :cascade do |t|
    t.string "request_id", null: false
    t.string "requester_id", null: false
    t.string "approver_id", null: false
    t.integer "shift_id"
    t.string "status", default: "pending"
    t.datetime "requested_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "responded_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_shift_exchanges_on_approver_id"
    t.index ["request_id"], name: "index_shift_exchanges_on_request_id", unique: true
    t.index ["requester_id"], name: "index_shift_exchanges_on_requester_id"
    t.index ["status"], name: "index_shift_exchanges_on_status"
  end

  create_table "shifts", force: :cascade do |t|
    t.string "employee_id", null: false
    t.date "shift_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.boolean "is_modified", default: false
    t.string "original_employee_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_shifts_on_employee_id"
    t.index ["shift_date", "start_time", "end_time"], name: "index_shifts_on_shift_date_and_start_time_and_end_time"
    t.index ["shift_date"], name: "index_shifts_on_shift_date"
  end

  create_table "verification_codes", force: :cascade do |t|
    t.string "line_user_id"
    t.string "employee_id"
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_verification_codes_on_code"
    t.index ["employee_id"], name: "index_verification_codes_on_employee_id"
    t.index ["expires_at"], name: "index_verification_codes_on_expires_at"
  end

  add_foreign_key "employee_line_accounts", "employees"
  add_foreign_key "shift_absences", "shifts", on_delete: :cascade
  add_foreign_key "shift_additions", "employees", column: "requester_id", primary_key: "employee_id", on_delete: :restrict
  add_foreign_key "shift_additions", "employees", column: "target_employee_id", primary_key: "employee_id", on_delete: :restrict
  add_foreign_key "shift_exchanges", "employees", column: "approver_id", primary_key: "employee_id", on_delete: :restrict
  add_foreign_key "shift_exchanges", "employees", column: "requester_id", primary_key: "employee_id", on_delete: :restrict
  add_foreign_key "shift_exchanges", "shifts", on_delete: :restrict
  add_foreign_key "shifts", "employees", column: "original_employee_id", primary_key: "employee_id", on_delete: :restrict
  add_foreign_key "shifts", "employees", primary_key: "employee_id", on_delete: :restrict
  add_foreign_key "verification_codes", "employees", primary_key: "employee_id", on_delete: :restrict
end
