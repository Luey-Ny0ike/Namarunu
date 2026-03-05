# == Schema Information
#
# Table name: lead_submissions
#
#  id                   :integer          not null, primary key
#  business_name        :string           not null
#  instagram_url        :string
#  instagram_handle     :string
#  tiktok_url           :string
#  tiktok_handle        :string
#  phone_raw            :string
#  phone_normalized     :string
#  location             :string
#  notes                :text
#  submitted_by_user_id :integer          not null
#  lead_id              :integer
#  editable_until       :datetime         not null
#  locked_at            :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  match_outcome        :string
#  matched_field        :string
#

# frozen_string_literal: true

class LeadSubmission < ApplicationRecord
  MATCH_OUTCOMES = {
    attached_existing: "attached_existing",
    created_new: "created_new"
  }.freeze

  belongs_to :submitted_by_user, class_name: "User", inverse_of: :submitted_lead_submissions
  belongs_to :lead, optional: true, inverse_of: :lead_submissions

  enum :match_outcome, MATCH_OUTCOMES, validate: { allow_nil: true }, prefix: true

  before_validation :normalize_fields
  before_validation :set_default_editable_until, on: :create

  validates :business_name, presence: true
  validate :must_have_at_least_one_identifier

  def editable_now?(time = Time.current)
    locked_at.nil? && time <= editable_until
  end

  def lock!
    update!(locked_at: Time.current)
  end

  def extract_instagram_handle(value = instagram_url)
    extract_handle(value, domain_pattern: /instagram\.com\/([^\/\?#]+)/i)
  end

  def extract_tiktok_handle(value = tiktok_url)
    extract_handle(value, domain_pattern: /tiktok\.com\/@([^\/\?#]+)/i)
  end

  def match_outcome_label
    case match_outcome
    when "attached_existing"
      "Attached to existing lead"
    when "created_new"
      "Created new lead"
    else
      "Match result unavailable"
    end
  end

  private

  def normalize_fields
    self.business_name = business_name.to_s.strip.presence
    self.instagram_url = instagram_url.to_s.strip.presence
    self.tiktok_url = tiktok_url.to_s.strip.presence
    self.phone_raw = phone_raw.to_s.strip.presence
    self.location = location.to_s.strip.presence

    self.instagram_handle = extract_instagram_handle
    self.tiktok_handle = extract_tiktok_handle
    self.phone_normalized = normalize_phone(phone_raw)
  end

  def set_default_editable_until
    return if editable_until.present?

    self.editable_until = (created_at || Time.current) + 30.minutes
  end

  def must_have_at_least_one_identifier
    return if instagram_url.present? || tiktok_url.present? || phone_raw.present?

    errors.add(:base, "must include at least one identifier")
  end

  def extract_handle(value, domain_pattern:)
    raw = value.to_s.strip
    return nil if raw.blank?

    candidate =
      if raw.start_with?("@")
        raw.delete_prefix("@")
      elsif (match = raw.match(domain_pattern))
        match[1]
      elsif raw.match?(/\Ahttps?:\/\//i)
        nil
      else
        raw
      end

    normalize_handle(candidate)
  end

  def normalize_handle(value)
    handle = value.to_s.strip.downcase.gsub(/\A@+/, "")
    token = handle[/[a-z0-9._]+/, 0]
    token.presence
  end

  def normalize_phone(value)
    without_extension = value.to_s.sub(/(?:ext\.?|extension|x)\s*\d+\s*\z/i, "")
    digits = without_extension.gsub(/\D/, "")
    return nil if digits.blank? || digits.length < 9

    # Assumption: contributors may submit local or international numbers.
    # We keep digits only and persist the right-most 9-12 digits so
    # equivalent numbers with country codes normalize to a consistent value.
    digits[-12, 12]
  end
end
