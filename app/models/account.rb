# == Schema Information
#
# Table name: accounts
#
#  id                     :integer          not null, primary key
#  name                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  converted_from_lead_id :integer
#

# frozen_string_literal: true

class Account < ApplicationRecord
  STATUSES = {
    pending: "pending",
    active: "active",
    cancelled: "cancelled"
  }.freeze

  belongs_to :converted_from_lead, class_name: "Lead", optional: true, inverse_of: :converted_account
  belongs_to :owner_user, class_name: "User", optional: true

  has_many :contacts, dependent: :destroy, inverse_of: :account
  has_many :demos, dependent: :nullify

  accepts_nested_attributes_for :contacts, reject_if: :all_blank

  enum :status, STATUSES, default: :pending, validate: true

  before_validation :normalize_social_handles
  before_validation :populate_social_urls_from_handles

  validates :name, presence: true

  private

  def normalize_social_handles
    self.instagram_handle = normalized_handle(instagram_handle)
    self.tiktok_handle = normalized_handle(tiktok_handle)
  end

  def populate_social_urls_from_handles
    if instagram_handle.present? && instagram_url.blank?
      self.instagram_url = "https://instagram.com/#{instagram_handle}"
    end

    if tiktok_handle.present? && tiktok_url.blank?
      self.tiktok_url = "https://www.tiktok.com/@#{tiktok_handle}"
    end
  end

  def normalized_handle(value)
    return if value.blank?

    value.to_s.strip.downcase.sub(/\A@+/, "")
  end
end
