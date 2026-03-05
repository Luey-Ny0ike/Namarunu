# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadConverter do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  def build_lead(owner:)
    Lead.create!(
      business_name: "Acme Co",
      owner_user: owner,
      industry: "fashion",
      location: "Nairobi",
      instagram_handle: "acme.store",
      instagram_url: "https://www.instagram.com/acme.store/",
      tiktok_handle: "acmetok",
      tiktok_url: "https://www.tiktok.com/@acmetok",
      facebook_url: "https://facebook.com/acme",
      status: :qualified,
      lead_contacts_attributes: [
        { name: "Jane", email: "JANE@EXAMPLE.COM", phone: "+254-712-000-111", role: "Owner" },
        { name: "John", phone: "+254 712 000 111 ext 9", role: "Ops" },
        { name: "", phone: "N/A", email: "", role: "Assistant" }
      ]
    )
  end

  it "creates account from lead, copies profile fields, and writes account_created activity" do
    actor = build_user(:sales_rep)
    lead = build_lead(owner: actor)

    account = nil
    expect do
      account = described_class.call(lead, actor_user: actor)
    end.to change(Account, :count).by(1)
      .and change(Contact, :count).by(3)
      .and change { Activity.where(action_type: "account_created").count }.by(1)

    lead.reload
    expect(account).to eq(lead.converted_account)
    expect(account.name).to eq("Acme Co")
    expect(account.industry).to eq("fashion")
    expect(account.location).to eq("Nairobi")
    expect(account.instagram_handle).to eq("acme.store")
    expect(account.instagram_url).to eq("https://www.instagram.com/acme.store/")
    expect(account.tiktok_handle).to eq("acmetok")
    expect(account.tiktok_url).to eq("https://www.tiktok.com/@acmetok")
    expect(account.facebook_url).to eq("https://facebook.com/acme")
    expect(account.status).to eq("pending")
    expect(account.owner_user_id).to eq(actor.id)
    expect(account.converted_from_lead_id).to eq(lead.id)
    expect(lead.converted_at).to be_present

    activity = Activity.where(subject: lead, action_type: "account_created").order(:created_at).last
    expect(activity.metadata).to include("account_id" => account.id)
  end

  it "is idempotent for account creation and still migrates missing lead contacts" do
    actor = build_user(:sales_rep)
    lead = build_lead(owner: actor)
    account = described_class.call(lead, actor_user: actor)

    LeadContact.create!(lead: lead, email: "new.person@example.com", role: "Finance")

    expect do
      returned = described_class.call(lead, actor_user: actor)
      expect(returned).to eq(account)
    end.to change(Account, :count).by(0)
      .and change(Contact, :count).by(2)
      .and change { Activity.where(action_type: "account_created").count }.by(0)
  end

  it "deduplicates by lowercased email first, else by last-12-digit phone" do
    actor = build_user(:sales_rep)
    lead = Lead.create!(
      business_name: "Dupe Co",
      owner_user: actor,
      lead_contacts_attributes: [
        { name: "A", email: "OWNER@EXAMPLE.COM", phone: "+254 711 222 333" },
        { name: "B", email: "owner@example.com", phone: "+254 700 000 000" },
        { name: "C", phone: "+254 700 111 222" },
        { name: "D", phone: "254700111222" }
      ]
    )

    described_class.call(lead, actor_user: actor)

    account = lead.reload.converted_account
    expect(account.contacts.count).to eq(2)
    expect(account.contacts.where("LOWER(email) = ?", "owner@example.com").count).to eq(1)
    normalized_phones = account.contacts.map { |contact| contact.phone.to_s.gsub(/\D/, "").last(12) }
    expect(normalized_phones.count("254700111222")).to eq(1)
  end

  it "backfills lead demos with account_id when missing" do
    actor = build_user(:sales_rep)
    lead = build_lead(owner: actor)
    demo = Demo.create!(
      lead: lead,
      account: nil,
      scheduled_at: 1.day.from_now,
      duration_minutes: 30,
      created_by_user: actor,
      assigned_to_user: actor
    )

    account = described_class.call(lead, actor_user: actor)

    expect(demo.reload.account_id).to eq(account.id)
  end
end
