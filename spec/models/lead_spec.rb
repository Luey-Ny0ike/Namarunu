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
end
