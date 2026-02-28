# frozen_string_literal: true

class Activity < ApplicationRecord
  belongs_to :actor_user, class_name: "User"
  belongs_to :subject, polymorphic: true

  validates :action_type, :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, created_at: :desc) }

  def timeline_label
    case action_type
    when "lead_created"
      "Lead created"
    when "lead_updated"
      "Lead updated"
    when "lead_status_changed"
      from = metadata["from"].presence || "-"
      to = metadata["to"].presence || "-"
      "Status changed from #{from.humanize} to #{to.humanize}"
    else
      action_type.humanize
    end
  end
end
