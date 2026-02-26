# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :full_name
      t.string :phone_number
      t.string :role, default: 'user', null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, %i[full_name email_address role]
  end
end
