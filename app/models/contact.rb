# == Schema Information
#
# Table name: contacts
#
#  id         :integer          not null, primary key
#  account_id :integer          not null
#  name       :string           not null
#  phone      :string
#  email      :string
#  role       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :account, inverse_of: :contacts

  validate :phone_or_email_present

  private

  def phone_or_email_present
    return if phone.to_s.strip.present? || email.to_s.strip.present?

    errors.add(:base, "Provide at least a phone number or an email")
  end
end
