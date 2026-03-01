# frozen_string_literal: true

require "rails_helper"

RSpec.describe DemoPolicy do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  let(:rep) { build_user(:sales_rep) }
  let(:other_rep) { build_user(:sales_rep) }
  let(:manager) { build_user(:sales_manager) }
  let(:lead) do
    Lead.create!(
      business_name: "Policy Lead",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Primary", phone: "+15550001111" }]
    )
  end

  let(:own_demo) do
    Demo.create!(
      lead: lead,
      scheduled_at: 1.day.from_now,
      duration_minutes: 30,
      created_by_user: rep,
      assigned_to_user: rep
    )
  end

  let(:other_demo) do
    Demo.create!(
      lead: lead,
      scheduled_at: 1.day.from_now,
      duration_minutes: 30,
      created_by_user: other_rep,
      assigned_to_user: other_rep
    )
  end

  it "allows reps to read and update demos they own" do
    policy = described_class.new(rep, own_demo)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "prevents reps from managing demos they do not own" do
    policy = described_class.new(rep, other_demo)

    expect(policy.show?).to be(false)
    expect(policy.update?).to be(false)
  end

  it "allows managers to manage all demos" do
    policy = described_class.new(manager, other_demo)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "limits rep create when assigning to another user" do
    demo = Demo.new(
      lead: lead,
      scheduled_at: 1.day.from_now,
      duration_minutes: 30,
      created_by_user: rep,
      assigned_to_user: other_rep
    )

    expect(described_class.new(rep, demo).create?).to be(false)
    expect(described_class.new(manager, demo).create?).to be(true)
  end

  it "scopes reps to demos they created or are assigned" do
    own_demo
    other_demo

    result = described_class::Scope.new(rep, Demo).resolve

    expect(result).to include(own_demo)
    expect(result).not_to include(other_demo)
  end
end
