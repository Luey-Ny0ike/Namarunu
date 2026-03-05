# frozen_string_literal: true

class AddMeetingFieldsToDemos < ActiveRecord::Migration[8.2]
  def change
    add_column :demos, :meeting_type, :string, null: false, default: "virtual"
    add_column :demos, :meeting_location, :string

    add_index :demos, :meeting_type
  end
end
