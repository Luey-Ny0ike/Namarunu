# frozen_string_literal: true

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

ActiveRecord::Schema[8.2].define(version: 2026_03_06_032000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_catalog.plpgsql'

  create_table "accounts", force: :cascade do |t|
    t.datetime "activated_at"
    t.string "cancel_reason"
    t.datetime "cancelled_at"
    t.bigint "converted_from_lead_id"
    t.datetime "created_at", null: false
    t.string "facebook_url"
    t.string "industry"
    t.string "instagram_handle"
    t.string "instagram_url"
    t.string "location"
    t.string "name"
    t.bigint "owner_user_id"
    t.string "status", default: "pending", null: false
    t.string "tiktok_handle"
    t.string "tiktok_url"
    t.datetime "updated_at", null: false
    t.index ["converted_from_lead_id"], name: "index_accounts_on_converted_from_lead_id"
    t.index ["owner_user_id"], name: "index_accounts_on_owner_user_id"
    t.index ["status"], name: "index_accounts_on_status"
  end

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

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_contacts_on_account_id"
  end

  create_table "demos", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "assigned_to_user_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.string "demo_link"
    t.integer "duration_minutes", default: 30, null: false
    t.bigint "lead_id"
    t.string "meeting_location"
    t.string "meeting_type", default: "virtual", null: false
    t.text "notes"
    t.string "outcome"
    t.datetime "scheduled_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.string "virtual_meeting_link"
    t.index ["account_id"], name: "index_demos_on_account_id"
    t.index ["assigned_to_user_id", "scheduled_at"], name: "index_demos_on_assigned_to_user_id_and_scheduled_at"
    t.index ["assigned_to_user_id"], name: "index_demos_on_assigned_to_user_id"
    t.index ["created_by_user_id"], name: "index_demos_on_created_by_user_id"
    t.index ["lead_id"], name: "index_demos_on_lead_id"
    t.index ["meeting_type"], name: "index_demos_on_meeting_type"
    t.index ["outcome"], name: "index_demos_on_outcome"
    t.index ["scheduled_at"], name: "index_demos_on_scheduled_at"
    t.index ["status"], name: "index_demos_on_status"
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
    t.bigint "lead_id"
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
    t.index ["lead_id"], name: "index_inquiries_on_lead_id"
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
    t.string "name"
    t.string "phone"
    t.string "preferred_channel"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_lead_contacts_on_lead_id"
  end

  create_table "lead_submissions", force: :cascade do |t|
    t.string "business_name", null: false
    t.datetime "created_at", null: false
    t.datetime "editable_until", default: -> { "(CURRENT_TIMESTAMP + 'PT30M'::interval)" }, null: false
    t.string "instagram_handle"
    t.string "instagram_url"
    t.bigint "lead_id"
    t.string "location"
    t.datetime "locked_at"
    t.string "match_outcome"
    t.string "matched_field"
    t.text "notes"
    t.string "phone_normalized"
    t.string "phone_raw"
    t.bigint "submitted_by_user_id", null: false
    t.string "tiktok_handle"
    t.string "tiktok_url"
    t.datetime "updated_at", null: false
    t.index ["instagram_handle"], name: "index_lead_submissions_on_instagram_handle"
    t.index ["lead_id"], name: "index_lead_submissions_on_lead_id"
    t.index ["match_outcome"], name: "index_lead_submissions_on_match_outcome"
    t.index ["phone_normalized"], name: "index_lead_submissions_on_phone_normalized"
    t.index ["submitted_by_user_id"], name: "index_lead_submissions_on_submitted_by_user_id"
    t.index ["tiktok_handle"], name: "index_lead_submissions_on_tiktok_handle"
  end

  create_table "leads", force: :cascade do |t|
    t.string "business_name", null: false
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.string "facebook_url"
    t.string "industry"
    t.string "instagram_handle"
    t.string "instagram_url"
    t.datetime "invoice_sent_at"
    t.datetime "last_contacted_at"
    t.string "location"
    t.string "lost_reason"
    t.datetime "next_action_at"
    t.bigint "owner_user_id"
    t.string "source"
    t.string "status", default: "new", null: false
    t.string "temperature", default: "warm", null: false
    t.string "tiktok_handle"
    t.string "tiktok_url"
    t.datetime "updated_at", null: false
    t.index "lower((instagram_handle)::text)", name: "index_leads_on_lower_instagram_handle_unique", unique: true, where: "(instagram_handle IS NOT NULL)"
    t.index "lower((tiktok_handle)::text)", name: "index_leads_on_lower_tiktok_handle_unique", unique: true, where: "(tiktok_handle IS NOT NULL)"
    t.index ["invoice_sent_at"], name: "index_leads_on_invoice_sent_at"
    t.index ["lost_reason"], name: "index_leads_on_lost_reason"
    t.index ["next_action_at"], name: "index_leads_on_next_action_at"
    t.index ["owner_user_id"], name: "index_leads_on_owner_user_id"
    t.index ["status"], name: "index_leads_on_status"
    t.index ["temperature"], name: "index_leads_on_temperature"
  end

  create_table 'invoice_line_items', force: :cascade do |t|
    t.bigint 'amount_cents', null: false
    t.datetime 'created_at', null: false
    t.string 'description', null: false
    t.bigint 'invoice_id', null: false
    t.string 'kind', default: 'subscription', null: false
    t.jsonb 'metadata', default: {}, null: false
    t.integer 'quantity', default: 1, null: false
    t.bigint 'unit_amount_cents', null: false
    t.index ['invoice_id'], name: 'index_invoice_line_items_on_invoice_id'
  end

  create_table 'invoice_payments', force: :cascade do |t|
    t.bigint 'amount_cents', null: false
    t.datetime 'created_at', null: false
    t.string 'currency', null: false
    t.bigint 'invoice_id', null: false
    t.datetime 'paid_at'
    t.string 'provider', null: false
    t.string 'provider_ref'
    t.jsonb 'raw_payload', default: {}, null: false
    t.string 'status', default: 'pending', null: false
    t.index ['invoice_id'], name: 'index_invoice_payments_on_invoice_id'
    t.index %w[provider provider_ref], name: 'index_invoice_payments_on_provider_and_provider_ref'
  end

  create_table 'invoices', force: :cascade do |t|
    t.bigint 'amount_due_cents', default: 0, null: false
    t.bigint 'amount_paid_cents', default: 0, null: false
    t.string 'billing_period', null: false
    t.date 'billing_period_end', null: false
    t.date 'billing_period_start', null: false
    t.datetime 'created_at', null: false
    t.string 'currency', default: 'KES', null: false
    t.bigint 'discount_cents', default: 0, null: false
    t.datetime 'due_at'
    t.string 'invoice_number', null: false
    t.datetime 'issued_at'
    t.text 'notes'
    t.string 'plan_code', null: false
    t.string 'plan_type', null: false
    t.string 'status', default: 'draft', null: false
    t.bigint 'store_id', null: false
    t.bigint 'store_subscription_id'
    t.bigint 'subtotal_cents', default: 0, null: false
    t.bigint 'tax_cents', default: 0, null: false
    t.bigint 'total_cents', default: 0, null: false
    t.datetime 'updated_at', null: false
    t.index ['due_at'], name: 'index_invoices_on_due_at'
    t.index ['invoice_number'], name: 'index_invoices_on_invoice_number', unique: true
    t.index ['status'], name: 'index_invoices_on_status'
    t.index ['store_id'], name: 'index_invoices_on_store_id'
    t.index %w[store_subscription_id billing_period_start billing_period_end],
            name: 'idx_on_store_subscription_id_billing_period_start_b_a9db99846f', unique: true
  end

  create_table 'sessions', force: :cascade do |t|
    t.datetime 'created_at', null: false
    t.string 'ip_address'
    t.datetime 'updated_at', null: false
    t.string 'user_agent'
    t.bigint 'user_id', null: false
    t.index ['user_id'], name: 'index_sessions_on_user_id'
  end

  create_table 'store_subscriptions', force: :cascade do |t|
    t.string 'billing_period', null: false
    t.boolean 'cancel_at_period_end', default: false, null: false
    t.datetime 'created_at', null: false
    t.string 'currency', default: 'KES', null: false
    t.date 'current_period_end', null: false
    t.date 'current_period_start', null: false
    t.string 'plan_code', null: false
    t.integer 'quantity', default: 1, null: false
    t.string 'status', default: 'active', null: false
    t.bigint 'store_id', null: false
    t.bigint 'unit_amount_cents', null: false
    t.datetime 'updated_at', null: false
    t.index ['current_period_end'], name: 'index_store_subscriptions_on_current_period_end'
    t.index ['status'], name: 'index_store_subscriptions_on_status'
    t.index ['store_id'], name: 'index_store_subscriptions_on_store_id'
  end

  create_table 'stores', force: :cascade do |t|
    t.datetime 'created_at', null: false
    t.string 'currency', default: 'KES', null: false
    t.string 'email_address'
    t.string 'name', null: false
    t.string 'phone_number'
    t.datetime 'updated_at', null: false
    t.index ['email_address'], name: 'index_stores_on_email_address'
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

  add_foreign_key "accounts", "leads", column: "converted_from_lead_id"
  add_foreign_key "accounts", "users", column: "owner_user_id"
  add_foreign_key "activities", "users", column: "actor_user_id"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "demos", "accounts"
  add_foreign_key "demos", "leads"
  add_foreign_key "demos", "users", column: "assigned_to_user_id"
  add_foreign_key "demos", "users", column: "created_by_user_id"
  add_foreign_key "inquiries", "leads"
  add_foreign_key "inquiries", "users", column: "checked_out_by_id"
  add_foreign_key "inquiries", "users", column: "owner_id"
  add_foreign_key "lead_assignments", "leads"
  add_foreign_key "lead_assignments", "users"
  add_foreign_key "lead_contacts", "leads"
  add_foreign_key "lead_submissions", "leads"
  add_foreign_key "lead_submissions", "users", column: "submitted_by_user_id"
  add_foreign_key "leads", "users", column: "owner_user_id"
  add_foreign_key "sessions", "users"
end
