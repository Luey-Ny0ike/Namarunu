class MakeInvoiceStoreNullable < ActiveRecord::Migration[8.2]
  def change
    change_column_null :invoices, :store_id, true
  end
end
