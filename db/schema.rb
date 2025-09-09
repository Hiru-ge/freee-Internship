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

ActiveRecord::Schema[8.0].define(version: 2025_09_09_113815) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "employees", force: :cascade do |t|
    t.string "employee_id"
    t.string "password_hash"
    t.string "role"
    t.datetime "last_login_at"
    t.datetime "password_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_employees_on_employee_id", unique: true
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
end
