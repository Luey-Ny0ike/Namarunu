# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadContact, type: :model do
  let(:lead) { Lead.new(business_name: "Acme Co") }

  it "is valid with phone only when name is blank" do
    contact = described_class.new(lead: lead, name: "", phone: "+15551234567", email: "")

    expect(contact).to be_valid
  end

  it "is valid with email only when name is blank" do
    contact = described_class.new(lead: lead, name: "", phone: "", email: "jane@example.com")

    expect(contact).to be_valid
  end

  it "is invalid when both phone and email are blank" do
    contact = described_class.new(lead: lead, name: "", phone: "", email: "")

    expect(contact).not_to be_valid
    expect(contact.errors[:base]).to include("Provide at least a phone number or an email")
  end
end
