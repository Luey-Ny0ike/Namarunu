class CreateInvoices < ActiveRecord::Migration[8.2]
  def change
    create_table :invoices do |t|
      t.bigint :store_id, null: false
      t.bigint :store_subscription_id
      t.string :plan_code, null: false
      t.string :plan_type, null: false
      t.string :billing_period, null: false
      t.string :currency, null: false, default: "KES"
      t.string :invoice_number, null: false
      t.date :billing_period_start, null: false
      t.date :billing_period_end, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :issued_at
      t.datetime :due_at
      t.bigint :subtotal_cents, null: false, default: 0
      t.bigint :discount_cents, null: false, default: 0
      t.bigint :tax_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.bigint :amount_paid_cents, null: false, default: 0
      t.bigint :amount_due_cents, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :store_id
    add_index :invoices, :status
    add_index :invoices, :due_at
    add_index :invoices, [ :store_subscription_id, :billing_period_start, :billing_period_end ], unique: true
  end
end
