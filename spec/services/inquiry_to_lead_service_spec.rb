# frozen_string_literal: true

require "rails_helper"

RSpec.describe InquiryToLeadService do
  def build_user(role = :sales_manager)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  around do |example|
    Inquiry.skip_callback(:commit, :after, :sync_lead_from_inquiry!, on: :create)
    example.run
  ensure
    Inquiry.set_callback(:commit, :after, :sync_lead_from_inquiry!, on: :create)
  end

  it "creates a lead, contact, activity and links the inquiry" do
    actor = build_user(:sales_manager)
    inquiry = Inquiry.create!(
      full_name: "Jane Doe",
      phone_number: "+1 555 100 2000",
      email: "jane@example.com",
      business_name: "Acme Inc",
      owner: actor
    )

    expect do
      described_class.new(inquiry).call
    end.to change(Lead, :count).by(1)
      .and change(LeadContact, :count).by(1)
      .and change(Activity, :count).by(1)

    inquiry.reload
    lead = inquiry.lead

    expect(lead).to be_present
    expect(lead.source).to eq("website")
    expect(lead.owner_user_id).to be_nil

    contact = lead.lead_contacts.last
    expect(contact.name).to eq("Jane Doe")
    expect(contact.phone).to eq("+1 555 100 2000")
    expect(contact.email).to eq("jane@example.com")
    expect(contact.role).to eq("Owner")

    activity = Activity.last
    expect(activity.subject).to eq(lead)
    expect(activity.action_type).to eq("lead_created")
    expect(activity.metadata).to include("source" => "inquiry", "inquiry_id" => inquiry.id)
  end

  it "matches by normalized phone first" do
    existing_lead = Lead.create!(
      business_name: "Existing Co",
      source: "referral",
      lead_contacts_attributes: [{ name: "Existing", phone: "+254 711 122 233", email: "old@example.com" }]
    )
    inquiry = Inquiry.create!(
      full_name: "New Name",
      phone_number: "+254711122233",
      email: "new@example.com",
      business_name: "Renamed Co"
    )

    expect do
      described_class.new(inquiry).call
    end.to change(Lead, :count).by(0)

    expect(inquiry.reload.lead_id).to eq(existing_lead.id)
    expect(existing_lead.reload.business_name).to eq("Renamed Co")
    expect(existing_lead.source).to eq("website")
    expect(existing_lead.owner_user_id).to be_nil
  end

  it "matches by contact email when phone is absent" do
    existing_lead = Lead.create!(
      business_name: "Email Match Co",
      lead_contacts_attributes: [{ name: "Owner", email: "owner@matchme.com" }]
    )
    inquiry = Inquiry.create!(
      full_name: "Email Person",
      phone_number: "+15559876543",
      email: "OWNER@MATCHME.COM",
      business_name: "Updated Via Email"
    )
    inquiry.update_column(:phone_number, nil)

    described_class.new(inquiry).call

    expect(inquiry.reload.lead_id).to eq(existing_lead.id)
    expect(existing_lead.reload.business_name).to eq("Updated Via Email")
  end

  it "matches by business domain when available" do
    existing_lead = Lead.create!(
      business_name: "Domain Match Co",
      lead_contacts_attributes: [{ name: "Owner", email: "sales@domainmatch.com" }]
    )
    inquiry = Inquiry.create!(
      full_name: "Domain Owner",
      phone_number: "+15551239999",
      email: "owner@other.com",
      business_name: "Domain Updated",
      business_link: "https://www.domainmatch.com/shop"
    )
    inquiry.update_column(:phone_number, nil)
    inquiry.update_column(:email, nil)

    described_class.new(inquiry).call

    expect(inquiry.reload.lead_id).to eq(existing_lead.id)
    expect(existing_lead.reload.business_name).to eq("Domain Updated")
  end

  it "is idempotent when inquiry already has lead_id" do
    lead = Lead.create!(
      business_name: "Linked Already",
      source: "website",
      lead_contacts_attributes: [{ name: "Person", phone: "+15552345678" }]
    )
    inquiry = Inquiry.create!(
      full_name: "Already Linked",
      phone_number: "+15552345678",
      business_name: "Already Linked",
      lead: lead
    )

    expect do
      described_class.new(inquiry).call
    end.to change(Lead, :count).by(0)
      .and change(LeadContact, :count).by(0)
      .and change(Activity, :count).by(0)

    expect(inquiry.reload.lead_id).to eq(lead.id)
  end
end
