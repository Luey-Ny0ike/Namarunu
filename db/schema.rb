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

ActiveRecord::Schema[8.2].define(version: 2026_03_01_030000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.string "action_type", null: false
    t.bigint "actor_user_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_activities_on_action_type"
    t.index ["actor_user_id"], name: "index_activities_on_actor_user_id"
    t.index ["metadata"], name: "index_activities_on_metadata", using: :gin
    t.index ["occurred_at"], name: "index_activities_on_occurred_at"
    t.index ["subject_type", "subject_id"], name: "index_activities_on_subject"
  end

  create_table "inquiries", force: :cascade do |t|
    t.string "billing_type"
    t.string "business_link"
    t.string "business_name"
    t.string "business_type"
    t.bigint "checked_out_by_id"
    t.datetime "created_at", null: false
    t.string "domain_name"
    t.string "email"
    t.string "full_name"
    t.string "intent"
    t.text "message"
    t.bigint "owner_id"
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
    t.index ["checked_out_by_id"], name: "index_inquiries_on_checked_out_by_id"
    t.index ["owner_id"], name: "index_inquiries_on_owner_id"
  end

  create_table "lead_assignments", force: :cascade do |t|
    t.datetime "checked_out_at", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "lead_id", null: false
    t.string "release_reason"
    t.datetime "released_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_lead_assignments_on_expires_at"
    t.index ["lead_id", "released_at"], name: "index_lead_assignments_on_lead_id_and_released_at"
    t.index ["lead_id"], name: "index_lead_assignments_on_lead_id"
    t.index ["lead_id"], name: "index_lead_assignments_on_lead_id_unreleased", unique: true, where: "(released_at IS NULL)"
    t.index ["released_at"], name: "index_lead_assignments_on_released_at"
    t.index ["user_id"], name: "index_lead_assignments_on_user_id"
  end

  create_table "lead_contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "lead_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "preferred_channel"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_lead_contacts_on_lead_id"
  end

  create_table "leads", force: :cascade do |t|
    t.string "business_name", null: false
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.string "industry"
    t.datetime "last_contacted_at"
    t.string "location"
    t.datetime "next_action_at"
    t.bigint "owner_user_id"
    t.string "source"
    t.string "status", default: "new", null: false
    t.string "temperature", default: "warm", null: false
    t.datetime "updated_at", null: false
    t.index ["next_action_at"], name: "index_leads_on_next_action_at"
    t.index ["owner_user_id"], name: "index_leads_on_owner_user_id"
    t.index ["status"], name: "index_leads_on_status"
    t.index ["temperature"], name: "index_leads_on_temperature"
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
    t.string "role", default: "sales_rep", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["full_name", "email_address", "role"], name: "index_users_on_full_name_and_email_address_and_role"
  end

  add_foreign_key "activities", "users", column: "actor_user_id"
  add_foreign_key "inquiries", "users", column: "checked_out_by_id"
  add_foreign_key "inquiries", "users", column: "owner_id"
  add_foreign_key "lead_assignments", "leads"
  add_foreign_key "lead_assignments", "users"
  add_foreign_key "lead_contacts", "leads"
  add_foreign_key "leads", "users", column: "owner_user_id"
  add_foreign_key "sessions", "users"
end
