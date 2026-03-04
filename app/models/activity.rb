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
    when "checked_out"
      if metadata["expires_at"].present?
        parsed_expires_at = Time.zone.parse(metadata["expires_at"].to_s)
        parsed_expires_at ? "Lead checked out until #{I18n.l(parsed_expires_at, format: :short)}" : "Lead checked out"
      else
        "Lead checked out"
      end
    when "released"
      "Lead checkout released"
    when "reassigned"
      "Lead checkout reassigned"
    when "expired"
      "Lead checkout expired"
    when "call_attempt_logged"
      outcome = metadata["outcome"].presence || "unknown"
      "Call attempt logged (#{outcome.humanize})"
    when "demo_booked"
      scheduled_at = metadata["scheduled_at"].presence
      if scheduled_at.present?
        parsed_scheduled_at = Time.zone.parse(scheduled_at.to_s)
        parsed_scheduled_at ? "Demo booked for #{I18n.l(parsed_scheduled_at, format: :short)}" : "Demo booked"
      else
        "Demo booked"
      end
    when "demo_updated"
      "Demo details updated"
    when "demo_status_changed"
      from = metadata["from"].presence || "-"
      to = metadata["to"].presence || "-"
      "Demo status changed from #{from.humanize} to #{to.humanize}"
    when "converted"
      "Lead converted to account"
    when "create_invoice"
      invoice_number = metadata["invoice_number"].presence
      invoice_number.present? ? "Invoice ##{invoice_number} created" : "Invoice created"
    else
      action_type.humanize
    end
  end
end
