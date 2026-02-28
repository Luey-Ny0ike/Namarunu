# frozen_string_literal: true

class LeadContact < ApplicationRecord
  CHANNEL_OPTIONS = %w[phone email whatsapp sms].freeze

  belongs_to :lead, inverse_of: :lead_contacts

  validates :name, presence: true
  validate :phone_or_email_present

  private

  def phone_or_email_present
    return if phone.present? || email.present?

    errors.add(:base, "Provide at least a phone number or an email")
  end
end
