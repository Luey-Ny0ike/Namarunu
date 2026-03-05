# frozen_string_literal: true

class AddLeadReferenceToInquiries < ActiveRecord::Migration[8.2]
  def change
    add_reference :inquiries, :lead, null: true, foreign_key: true
  end
end
