class AddRecipientFieldsToInvoices < ActiveRecord::Migration[8.2]
  def change
    add_column :invoices, :name, :string
    add_column :invoices, :email_address, :string
    add_column :invoices, :phone_number, :string
  end
end
