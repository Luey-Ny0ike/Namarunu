# frozen_string_literal: true

class CreateInvoicePayments < ActiveRecord::Migration[8.2]
  def change
    create_table :invoice_payments do |t|
      t.bigint :invoice_id, null: false
      t.string :provider, null: false
      t.string :provider_ref
      t.string :status, null: false, default: 'pending'
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.datetime :paid_at
      t.jsonb :raw_payload, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :invoice_payments, :invoice_id
    add_index :invoice_payments, %i[provider provider_ref]
  end
end
