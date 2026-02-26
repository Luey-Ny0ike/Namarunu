# frozen_string_literal: true

class CreateStores < ActiveRecord::Migration[8.2]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.string :email_address
      t.string :phone_number
      t.string :currency, null: false, default: 'KES'

      t.timestamps
    end

    add_index :stores, :email_address
  end
end
