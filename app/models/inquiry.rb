# frozen_string_literal: true

# == Schema Information
#
# Table name: inquiries
#
#  id                 :bigint           not null, primary key
#  billing_type       :string
#  business_link      :string
#  business_name      :string
#  business_type      :string
#  created_at         :datetime         not null
#  domain_name        :string
#  email              :string
#  full_name          :string
#  intent             :string
#  message            :text
#  phone_number       :string
#  plan               :string
#  preffered_name     :string
#  sell_in_store      :boolean
#  source             :string           default("marketing_get_started"), not null
#  status             :string           default("new"), not null
#  store_name         :string
#  updated_at         :datetime         not null
#  utm_campaign       :string
#  utm_content        :string
#  utm_medium         :string
#  utm_source         :string
#  utm_term           :string
#  web_administration :string
#
class Inquiry < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true, inverse_of: :owned_inquiries
  belongs_to :checked_out_by, class_name: "User", optional: true, inverse_of: :checked_out_inquiries

  INTENT_OPTIONS = %w[
    start_selling_online
    improve_existing_online_store
    need_pos
    need_both
    more_information
  ].freeze

  NORMALIZED_STRING_FIELDS = %i[
    full_name
    phone_number
    email
    business_name
    business_type
    business_link
    intent
    source
    status
    utm_source
    utm_medium
    utm_campaign
    utm_term
    utm_content
  ].freeze

  attr_accessor :website, :require_business_context

  before_validation :normalize_string_fields

  validates :full_name, :phone_number, :business_name, presence: true
  validates :intent, inclusion: { in: INTENT_OPTIONS }, allow_blank: true
  validates :business_type, presence: true, if: :require_business_context
  validates :sell_in_store, inclusion: { in: [true, false] }, if: :require_business_context

  validate :phone_number_has_reasonable_length

  def owned_or_checked_out_by?(user)
    return false if user.blank?

    owner_id == user.id || checked_out_by_id == user.id
  end

  private

  def normalize_string_fields
    NORMALIZED_STRING_FIELDS.each do |field|
      self[field] = self[field].to_s.strip.presence
    end
  end

  def phone_number_has_reasonable_length
    return if phone_number.blank?

    digits = phone_number.gsub(/\D/, "")
    return if digits.length.between?(7, 15)

    errors.add(:phone_number, "is invalid")
  end
end
