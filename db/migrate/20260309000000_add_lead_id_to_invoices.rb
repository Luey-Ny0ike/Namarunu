# frozen_string_literal: true

class AddLeadIdToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :lead_id, :bigint
    add_index :invoices, :lead_id, unique: true
  end
end
