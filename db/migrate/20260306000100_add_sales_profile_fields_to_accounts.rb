# frozen_string_literal: true

class AddSalesProfileFieldsToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :industry, :string
    add_column :accounts, :location, :string
    add_column :accounts, :instagram_handle, :string
    add_column :accounts, :instagram_url, :string
    add_column :accounts, :tiktok_handle, :string
    add_column :accounts, :tiktok_url, :string
    add_column :accounts, :facebook_url, :string
    add_column :accounts, :status, :string, null: false, default: "pending"
    add_column :accounts, :activated_at, :datetime
    add_column :accounts, :cancelled_at, :datetime
    add_column :accounts, :cancel_reason, :string

    add_reference :accounts, :owner_user, null: true, foreign_key: { to_table: :users }, index: true

    add_index :accounts, :status
  end
end
