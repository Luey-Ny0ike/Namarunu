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

ActiveRecord::Schema[8.2].define(version: 2026_02_28_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "inquiries", force: :cascade do |t|
    t.string "billing_type"
    t.string "business_link"
    t.string "business_name"
    t.string "business_type"
    t.datetime "created_at", null: false
    t.string "domain_name"
    t.string "email"
    t.string "full_name"
    t.string "intent"
    t.text "message"
    t.string "phone_number"
    t.string "plan"
    t.string "preffered_name"
    t.boolean "sell_in_store"
    t.string "source", default: "marketing_get_started", null: false
    t.string "status", default: "new", null: false
    t.string "store_name"
    t.datetime "updated_at", null: false
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "web_administration"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "full_name"
    t.string "password_digest", null: false
    t.string "phone_number"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["full_name", "email_address", "role"], name: "index_users_on_full_name_and_email_address_and_role"
  end

  add_foreign_key "sessions", "users"
end
