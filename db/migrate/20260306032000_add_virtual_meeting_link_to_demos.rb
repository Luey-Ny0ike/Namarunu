# frozen_string_literal: true

class AddVirtualMeetingLinkToDemos < ActiveRecord::Migration[8.2]
  def change
    add_column :demos, :virtual_meeting_link, :string
  end
end
