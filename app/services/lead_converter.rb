# frozen_string_literal: true

require "set"

class LeadConverter
  def self.call(lead, actor_user:)
    new(lead, actor_user: actor_user).call
  end

  def initialize(lead, actor_user:)
    @lead = lead
    @actor_user = actor_user
  end

  def call
    account = Account.find_by(converted_from_lead_id: lead.id)
    account_created = false

    Lead.transaction do
      if account.blank?
        account = Account.create!(account_attributes)
        account_created = true
      end

      migrate_lead_contacts!(account)
      lead.update!(converted_at: Time.current) if lead.converted_at.blank?
      lead.demos.where(account_id: nil).update_all(account_id: account.id)

      if account_created
        Activity.create!(
          actor_user: actor_user,
          subject: lead,
          action_type: "account_created",
          metadata: { account_id: account.id },
          occurred_at: Time.current
        )
      end
    end

    account
  end

  private

  attr_reader :lead, :actor_user

  def account_attributes
    {
      name: lead.business_name,
      industry: lead.industry,
      location: lead.location,
      instagram_handle: lead.instagram_handle,
      instagram_url: lead.instagram_url,
      tiktok_handle: lead.tiktok_handle,
      tiktok_url: lead.tiktok_url,
      facebook_url: lead.facebook_url,
      status: "pending",
      owner_user_id: lead.owner_user_id,
      converted_from_lead_id: lead.id
    }.compact
  end

  def migrate_lead_contacts!(account)
    existing_emails = account.contacts.where.not(email: [nil, ""]).pluck(:email).map { |value| normalized_email(value) }.compact.to_set
    existing_phones = account.contacts.where.not(phone: [nil, ""]).pluck(:phone).map { |value| normalized_phone_digits(value) }.compact.to_set

    lead.lead_contacts.order(:id).each do |lead_contact|
      email_key = normalized_email(lead_contact.email)
      phone_key = normalized_phone_digits(lead_contact.phone)

      if email_key.present?
        next if existing_emails.include?(email_key)
      elsif phone_key.present?
        next if existing_phones.include?(phone_key)
      end

      created = account.contacts.create!(
        name: lead_contact.name.to_s.strip.presence,
        phone: lead_contact.phone.to_s.strip.presence,
        email: lead_contact.email.to_s.strip.presence,
        role: lead_contact.role.to_s.strip.presence
      )

      existing_emails << normalized_email(created.email) if created.email.present?
      existing_phones << normalized_phone_digits(created.phone) if created.phone.present?
    end
  end

  def normalized_email(value)
    value.to_s.strip.downcase.presence
  end

  def normalized_phone_digits(value)
    digits = value.to_s.gsub(/\D/, "")
    return nil if digits.blank?

    digits.last(12)
  end
end
