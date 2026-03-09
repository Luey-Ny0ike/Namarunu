# frozen_string_literal: true

class CreateInvoiceLineItems < ActiveRecord::Migration[8.2]
  def change
    create_table :invoice_line_items do |t|
      t.bigint :invoice_id, null: false
      t.string :kind, null: false, default: 'subscription'
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.bigint :unit_amount_cents, null: false
      t.bigint :amount_cents, null: false
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :invoice_line_items, :invoice_id
  end
end
