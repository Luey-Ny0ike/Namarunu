# frozen_string_literal: true

require "uri"

class InquiryToLeadService
  attr_reader :inquiry

  def initialize(inquiry)
    @inquiry = inquiry
  end

  def call
    return inquiry.lead if inquiry.lead_id.present?

    lead = find_matching_lead
    created_new_lead = lead.blank?
    lead ||= create_lead!
    update_lead!(lead)
    sync_contact!(lead)
    inquiry.update_column(:lead_id, lead.id)
    create_activity!(lead) if created_new_lead
    lead
  end

  private

  def find_matching_lead
    find_by_phone || find_by_email || find_by_business_domain
  end

  def find_by_phone
    normalized_phone = LeadSubmissionMatcher.normalize_phone(inquiry.phone_number)
    return if normalized_phone.blank?

    LeadContact.includes(:lead).where.not(phone: [nil, ""]).find do |contact|
      LeadSubmissionMatcher.normalize_phone(contact.phone) == normalized_phone
    end&.lead
  end

  def find_by_email
    email = inquiry.email.to_s.strip.downcase
    return if email.blank?

    Lead.joins(:lead_contacts).where("LOWER(lead_contacts.email) = ?", email).order("leads.created_at DESC").first
  end

  def find_by_business_domain
    inquiry_domain = normalized_domain(inquiry.business_link)
    return if inquiry_domain.blank?

    lead = Lead.joins(:lead_contacts)
      .where.not(lead_contacts: { email: [nil, ""] })
      .find do |candidate|
        candidate.lead_contacts.any? { |contact| normalized_domain_from_email(contact.email) == inquiry_domain }
      end
    return lead if lead.present?

    Lead.where.not(facebook_url: [nil, ""]).find { |candidate| normalized_domain(candidate.facebook_url) == inquiry_domain } ||
      Lead.where.not(instagram_url: [nil, ""]).find { |candidate| normalized_domain(candidate.instagram_url) == inquiry_domain } ||
      Lead.where.not(tiktok_url: [nil, ""]).find { |candidate| normalized_domain(candidate.tiktok_url) == inquiry_domain }
  end

  def create_lead!
    Lead.create!(
      business_name: inquiry.business_name,
      source: "website",
      owner_user_id: nil,
      lead_contacts_attributes: [contact_attributes]
    )
  end

  def update_lead!(lead)
    attrs = {
      business_name: inquiry.business_name,
      source: "website",
      owner_user_id: nil
    }
    attrs[:location] = inquiry.location if inquiry.respond_to?(:location) && inquiry.location.present?
    lead.update!(attrs)
  end

  def sync_contact!(lead)
    phone = inquiry.phone_number.to_s.strip.presence
    email = inquiry.email.to_s.strip.downcase.presence
    return if phone.blank? && email.blank?

    matching_contact = lead.lead_contacts.find do |contact|
      same_phone = phone.present? && LeadSubmissionMatcher.normalize_phone(contact.phone) == LeadSubmissionMatcher.normalize_phone(phone)
      same_email = email.present? && contact.email.to_s.strip.downcase == email
      same_phone || same_email
    end

    if matching_contact.present?
      matching_contact.update!(
        name: contact_attributes[:name] || matching_contact.name,
        phone: contact_attributes[:phone] || matching_contact.phone,
        email: contact_attributes[:email] || matching_contact.email,
        role: contact_attributes[:role] || matching_contact.role
      )
    else
      lead.lead_contacts.create!(contact_attributes)
    end
  end

  def create_activity!(lead)
    actor = inquiry.owner || Current.user || User.order(:id).first
    return if actor.blank?

    Activity.create!(
      actor_user: actor,
      subject: lead,
      action_type: "lead_created",
      metadata: {
        source: "inquiry",
        inquiry_id: inquiry.id
      },
      occurred_at: Time.current
    )
  end

  def normalized_domain(url_value)
    raw = url_value.to_s.strip
    return if raw.blank?

    parsed = URI.parse(raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}")
    parsed.host.to_s.downcase.sub(/\Awww\./, "").presence
  rescue URI::InvalidURIError
    nil
  end

  def normalized_domain_from_email(email)
    email.to_s.split("@", 2).last.to_s.downcase.sub(/\Awww\./, "").presence
  end

  def contact_attributes
    {
      name: inquiry.full_name.to_s.strip.presence,
      phone: inquiry.phone_number.to_s.strip.presence,
      email: inquiry.email.to_s.strip.downcase.presence,
      role: "Owner"
    }
  end
end
