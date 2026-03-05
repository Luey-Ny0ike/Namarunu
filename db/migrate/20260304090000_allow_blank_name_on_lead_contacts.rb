# frozen_string_literal: true

class AllowBlankNameOnLeadContacts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :lead_contacts, :name, true
  end
end
