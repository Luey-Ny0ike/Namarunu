# frozen_string_literal: true

class AddAssignmentFieldsToInquiries < ActiveRecord::Migration[8.2]
  def change
    add_reference :inquiries, :owner, foreign_key: { to_table: :users }
    add_reference :inquiries, :checked_out_by, foreign_key: { to_table: :users }
  end
end
