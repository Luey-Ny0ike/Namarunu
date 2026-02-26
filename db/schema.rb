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

ActiveRecord::Schema[8.2].define(version: 2026_02_26_165043) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "inquiries", force: :cascade do |t|
    t.string "billing_type"
    t.datetime "created_at", null: false
    t.string "domain_name"
    t.string "email"
    t.string "full_name"
    t.text "message"
    t.string "phone_number"
    t.string "plan"
    t.string "preffered_name"
    t.string "store_name"
    t.datetime "updated_at", null: false
    t.string "web_administration"
  end

  create_table "invoice_line_items", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "invoice_id", null: false
    t.string "kind", default: "subscription", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "unit_amount_cents", null: false
    t.index ["invoice_id"], name: "index_invoice_line_items_on_invoice_id"
  end

  create_table "invoice_payments", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.bigint "invoice_id", null: false
    t.datetime "paid_at"
    t.string "provider", null: false
    t.string "provider_ref"
    t.jsonb "raw_payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.index ["invoice_id"], name: "index_invoice_payments_on_invoice_id"
    t.index ["provider", "provider_ref"], name: "index_invoice_payments_on_provider_and_provider_ref"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "amount_due_cents", default: 0, null: false
    t.bigint "amount_paid_cents", default: 0, null: false
    t.string "billing_period", null: false
    t.date "billing_period_end", null: false
    t.date "billing_period_start", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "KES", null: false
    t.bigint "discount_cents", default: 0, null: false
    t.datetime "due_at"
    t.string "invoice_number", null: false
    t.datetime "issued_at"
    t.text "notes"
    t.string "plan_code", null: false
    t.string "plan_type", null: false
    t.string "status", default: "draft", null: false
    t.bigint "store_id", null: false
    t.bigint "store_subscription_id"
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["due_at"], name: "index_invoices_on_due_at"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["store_id"], name: "index_invoices_on_store_id"
    t.index ["store_subscription_id", "billing_period_start", "billing_period_end"], name: "idx_on_store_subscription_id_billing_period_start_b_a9db99846f", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "store_subscriptions", force: :cascade do |t|
    t.string "billing_period", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "KES", null: false
    t.date "current_period_end", null: false
    t.date "current_period_start", null: false
    t.string "plan_code", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", default: "active", null: false
    t.bigint "store_id", null: false
    t.bigint "unit_amount_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["current_period_end"], name: "index_store_subscriptions_on_current_period_end"
    t.index ["status"], name: "index_store_subscriptions_on_status"
    t.index ["store_id"], name: "index_store_subscriptions_on_store_id"
  end

  create_table "stores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "KES", null: false
    t.string "email_address"
    t.string "name", null: false
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_stores_on_email_address"
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
