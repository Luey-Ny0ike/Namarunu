# frozen_string_literal: true

class AddInvoiceAndLossFieldsToLeads < ActiveRecord::Migration[8.2]
  def change
    add_column :leads, :invoice_sent_at, :datetime
    add_column :leads, :lost_reason, :string

    add_index :leads, :invoice_sent_at
    add_index :leads, :lost_reason
  end
end
