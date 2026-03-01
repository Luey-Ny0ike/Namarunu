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
  let(:assignee) { build_user(:sales_rep) }
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
    other_rep = build_user(:sales_rep)
    other_policy = described_class.new(other_rep, lead)

    LeadAssignment.create!(
      lead: lead,
      user: assignee,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )
    assignee_policy = described_class.new(assignee, lead)

    expect(own_policy.update?).to be(true)
    expect(assignee_policy.update?).to be(true)
    expect(other_policy.update?).to be(false)
  end

  it "allows assignee to release and managers to force release and reassign" do
    assignment = LeadAssignment.create!(
      lead: lead,
      user: assignee,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    assignee_policy = described_class.new(assignee, lead)
    manager = build_user(:sales_manager)
    manager_policy = described_class.new(manager, lead)
    other_rep_policy = described_class.new(build_user(:sales_rep), lead)

    expect(assignment).to be_active
    expect(assignee_policy.release?).to be(true)
    expect(other_rep_policy.release?).to be(false)
    expect(manager_policy.force_release?).to be(true)
    expect(manager_policy.reassign_checkout?).to be(true)
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

  it "includes actively checked out leads in sales rep scope" do
    another_rep = build_user(:sales_rep)
    lead_with_checkout = Lead.create!(
      business_name: "Checkout Scoped Co",
      owner_user: another_rep,
      lead_contacts_attributes: [{ name: "Scoped Contact", phone: "+15550002222" }]
    )
    LeadAssignment.create!(
      lead: lead_with_checkout,
      user: owner,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    result = described_class::Scope.new(owner, Lead).resolve

    expect(result).to include(lead_with_checkout)
  end

  it "allows conversion only for eligible statuses and when not already converted" do
    manager = build_user(:sales_manager)
    eligible_lead = Lead.create!(
      business_name: "Eligible Co",
      owner_user: owner,
      status: :qualified,
      lead_contacts_attributes: [{ name: "Contact", phone: "+15559990000" }]
    )
    ineligible_lead = Lead.create!(
      business_name: "Ineligible Co",
      owner_user: owner,
      status: :new,
      lead_contacts_attributes: [{ name: "Contact", phone: "+15559991111" }]
    )

    expect(described_class.new(manager, eligible_lead).convert?).to be(true)
    expect(described_class.new(manager, ineligible_lead).convert?).to be(false)

    Account.create!(name: "Existing Account", converted_from_lead: eligible_lead)
    expect(described_class.new(manager, eligible_lead.reload).convert?).to be(false)
  end
end
