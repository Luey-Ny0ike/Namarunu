# frozen_string_literal: true

class AddMessageToInquiries < ActiveRecord::Migration[6.0]
  def change
    add_column :inquiries, :message, :text
  end
end
