# frozen_string_literal: true

class CreateStoreSubscriptions < ActiveRecord::Migration[8.2]
  def change
    create_table :store_subscriptions do |t|
      t.bigint :store_id, null: false
      t.string :plan_code, null: false
      t.string :billing_period, null: false
      t.string :currency, null: false, default: 'KES'
      t.date :current_period_start, null: false
      t.date :current_period_end, null: false
      t.boolean :cancel_at_period_end, null: false, default: false
      t.string :status, null: false, default: 'active'
      t.integer :quantity, null: false, default: 1
      t.bigint :unit_amount_cents, null: false

      t.timestamps
    end

    add_index :store_subscriptions, :store_id
    add_index :store_subscriptions, :status
    add_index :store_subscriptions, :current_period_end
  end
end
