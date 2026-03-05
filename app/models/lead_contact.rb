# == Schema Information
#
# Table name: lead_contacts
#
#  id                :integer          not null, primary key
#  lead_id           :integer          not null
#  name              :string
#  phone             :string
#  email             :string
#  role              :string
#  preferred_channel :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

# frozen_string_literal: true

class LeadContact < ApplicationRecord
  CHANNEL_OPTIONS = %w[phone email whatsapp sms].freeze

  belongs_to :lead, inverse_of: :lead_contacts

  validate :phone_or_email_present

  private

  def phone_or_email_present
    return if phone.present? || email.present?

    errors.add(:base, "Provide at least a phone number or an email")
  end
end
