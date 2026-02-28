# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadPolicy do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  let(:owner) { build_user(:sales_rep) }
  let(:lead) do
    Lead.create!(
      business_name: "Acme Inc",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Primary Contact", phone: "+15551234567" }]
    )
  end

  it "allows super_admin full lead access" do
    policy = described_class.new(build_user(:super_admin), lead)

    expect(policy.index?).to be(true)
    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
  end

  it "allows sales_manager to update all leads" do
    policy = described_class.new(build_user(:sales_manager), lead)

    expect(policy.index?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "allows sales_rep to update owned leads only" do
    own_policy = described_class.new(owner, lead)
    other_policy = described_class.new(build_user(:sales_rep), lead)

    expect(own_policy.update?).to be(true)
    expect(other_policy.update?).to be(false)
  end

  it "scopes sales reps to owned leads" do
    another_rep = build_user(:sales_rep)
    other_lead = Lead.create!(
      business_name: "Other Co",
      owner_user: another_rep,
      lead_contacts_attributes: [{ name: "Other Contact", phone: "+15557654321" }]
    )

    result = described_class::Scope.new(owner, Lead).resolve

    expect(result).to contain_exactly(lead)
    expect(result).not_to include(other_lead)
  end
end
