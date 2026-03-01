# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.2]
  def change
    create_table :accounts do |t|
      t.string :name
      t.boolean :converted, null: false, default: false

      t.timestamps
    end

    add_index :accounts, :converted
  end
end
