# frozen_string_literal: true

class AllowBlankNameOnContacts < ActiveRecord::Migration[8.2]
  def change
    change_column_null :contacts, :name, true
  end
end
