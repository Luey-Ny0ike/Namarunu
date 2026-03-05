# frozen_string_literal: true

class LeadSubmissionMatcher
  attr_reader :submission
  attr_reader :matched_field, :matched_lead

  def initialize(submission)
    @submission = submission
  end

  def call
    LeadSubmission.transaction do
      ensure_submission_valid!

      lead, matched_field = find_matching_lead

      if lead.present?
        @matched_lead = lead
        @matched_field = matched_field
        attach_to_existing_lead!(lead, matched_field)
      else
        @matched_lead = create_lead_and_attach!
        @matched_field = nil
      end

      submission
    end
  end

  def preview_match
    ensure_submission_valid!
    lead, field = find_matching_lead
    { lead: lead, matched_field: field }
  end

  def attached_to_existing_lead?
    matched_lead.present? && matched_field.present?
  end

  def created_new_lead?
    matched_lead.present? && matched_field.blank?
  end

  def self.normalize_phone(value)
    digits = value.to_s.gsub(/\D/, "")
    return nil if digits.blank? || digits.length < 9

    digits[-12, 12]
  end

  private

  def ensure_submission_valid!
    return if submission.valid?

    raise ActiveRecord::RecordInvalid, submission
  end

  def find_matching_lead
    if submission.instagram_handle.present?
      lead = find_by_instagram_handle(submission.instagram_handle)
      return [lead, "instagram"] if lead.present?
    end

    if submission.tiktok_handle.present?
      lead = find_by_tiktok_handle(submission.tiktok_handle)
      return [lead, "tiktok"] if lead.present?
    end

    if submission.phone_normalized.present?
      lead = find_by_phone(submission.phone_normalized)
      return [lead, "phone"] if lead.present?
    end

    [nil, nil]
  end

  def find_by_instagram_handle(handle)
    normalized_handle = handle.to_s.downcase

    if Lead.column_names.include?("instagram_handle")
      direct_match = Lead.where("LOWER(leads.instagram_handle) = ?", normalized_handle).first
      return direct_match if direct_match.present?
    end

    Lead.joins(:lead_submissions)
      .where("LOWER(lead_submissions.instagram_handle) = ?", normalized_handle)
      .order("lead_submissions.created_at DESC")
      .first
  end

  def find_by_tiktok_handle(handle)
    normalized_handle = handle.to_s.downcase

    if Lead.column_names.include?("tiktok_handle")
      direct_match = Lead.where("LOWER(leads.tiktok_handle) = ?", normalized_handle).first
      return direct_match if direct_match.present?
    end

    Lead.joins(:lead_submissions)
      .where("LOWER(lead_submissions.tiktok_handle) = ?", normalized_handle)
      .order("lead_submissions.created_at DESC")
      .first
  end

  def find_by_phone(phone_normalized)
    if Lead.column_names.include?("phone_normalized")
      direct_match = Lead.where(phone_normalized: phone_normalized).first
      return direct_match if direct_match.present?
    end

    matching_contact = LeadContact.includes(:lead).where.not(phone: [nil, ""]).find do |contact|
      self.class.normalize_phone(contact.phone) == phone_normalized
    end
    matching_contact&.lead
  end

  def attach_to_existing_lead!(lead, matched_field)
    seed_missing_lead_socials!(lead)

    save_submission!(
      lead,
      match_outcome: LeadSubmission::MATCH_OUTCOMES[:attached_existing],
      matched_field: matched_field
    )
    create_activity!(
      lead: lead,
      action_type: "submission_attached",
      metadata: {
        submission_id: submission.id,
        matched_field: matched_field
      }
    )
  end

  def create_lead_and_attach!
    lead = Lead.create!(
      business_name: submission.business_name,
      location: submission.location,
      industry: nil,
      source: "contributor",
      owner_user_id: nil,
      instagram_handle: normalize_handle(submission.instagram_handle),
      tiktok_handle: normalize_handle(submission.tiktok_handle),
      facebook_url: normalized_submission_facebook_url
    )

    save_submission!(
      lead,
      match_outcome: LeadSubmission::MATCH_OUTCOMES[:created_new],
      matched_field: nil
    )
    create_activity!(
      lead: lead,
      action_type: "lead_created_from_submission",
      metadata: { submission_id: submission.id }
    )

    lead
  end

  def save_submission!(lead, match_outcome:, matched_field:)
    if submission.persisted?
      submission.update!(lead: lead, match_outcome: match_outcome, matched_field: matched_field)
    else
      submission.lead = lead
      submission.match_outcome = match_outcome
      submission.matched_field = matched_field
      submission.save!
    end
  end

  def create_activity!(lead:, action_type:, metadata:)
    Activity.create!(
      actor_user_id: submission.submitted_by_user_id,
      subject: lead,
      action_type: action_type,
      metadata: metadata,
      occurred_at: Time.current
    )
  end

  def seed_missing_lead_socials!(lead)
    lead.instagram_handle = normalize_handle(submission.instagram_handle) if lead.instagram_handle.blank?
    lead.tiktok_handle = normalize_handle(submission.tiktok_handle) if lead.tiktok_handle.blank?
    if lead.facebook_url.blank? && normalized_submission_facebook_url.present?
      lead.facebook_url = normalized_submission_facebook_url
    end

    return unless lead.changed?

    begin
      lead.save!
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
      Rails.logger.warn(
        "LeadSubmissionMatcher social seed skipped lead_id=#{lead.id} submission_id=#{submission.id} error=#{error.class}"
      )
      lead.reload
    end
  end

  def normalize_handle(value)
    value.to_s.strip.gsub(/\A@+/, "").downcase.presence
  end

  def normalized_submission_facebook_url
    return nil unless submission.respond_to?(:facebook_url)

    submission.facebook_url.to_s.strip.presence
  end
end
