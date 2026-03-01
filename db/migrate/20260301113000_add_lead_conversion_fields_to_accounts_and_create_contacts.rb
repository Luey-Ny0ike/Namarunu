# frozen_string_literal: true

class AddLeadConversionFieldsToAccountsAndCreateContacts < ActiveRecord::Migration[8.2]
  def change
    change_table :accounts, bulk: true do |t|
      t.references :converted_from_lead, foreign_key: { to_table: :leads }
      t.remove :converted
    end

    create_table :contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.string :role

      t.timestamps
    end
  end
end
