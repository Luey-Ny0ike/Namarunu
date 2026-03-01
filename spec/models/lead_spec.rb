# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lead, type: :model do
  it "requires at least one lead contact" do
    lead = described_class.new(business_name: "Acme")

    expect(lead).not_to be_valid
    expect(lead.errors[:lead_contacts]).to include("must include at least one contact")
  end

  it "is valid with one contact" do
    lead = described_class.new(
      business_name: "Acme",
      lead_contacts_attributes: [{ name: "Jane Doe", email: "jane@example.com" }]
    )

    expect(lead).to be_valid
  end

  it "returns only due follow-ups" do
    due = described_class.create!(
      business_name: "Due Co",
      next_action_at: 1.hour.ago,
      lead_contacts_attributes: [{ name: "Due Contact", phone: "+15550001111" }]
    )
    described_class.create!(
      business_name: "Later Co",
      next_action_at: 1.day.from_now,
      lead_contacts_attributes: [{ name: "Later Contact", phone: "+15550002222" }]
    )

    expect(described_class.follow_ups_due).to contain_exactly(due)
  end

  it "allows owner or active assignee to edit" do
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    assignee = User.create!(
      email_address: "assignee-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    other = User.create!(
      email_address: "other-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Editable Co",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Lead Contact", phone: "+15550003333" }]
    )
    LeadAssignment.create!(
      lead: lead,
      user: assignee,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    expect(lead.editable_by?(owner)).to be(true)
    expect(lead.editable_by?(assignee)).to be(true)
    expect(lead.editable_by?(other)).to be(false)
  end
end
