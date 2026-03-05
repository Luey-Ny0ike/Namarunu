# frozen_string_literal: true

require "rails_helper"

RSpec.describe InquiryPolicy do
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
  let(:checked_out_rep) { build_user(:sales_rep) }
  let(:inquiry) do
    Inquiry.create!(
      full_name: "Lead One",
      phone_number: "+15551234567",
      business_name: "Acme Inc",
      owner: owner,
      checked_out_by: checked_out_rep
    )
  end

  it "allows super_admin to do everything on leads" do
    user = build_user(:super_admin)
    policy = described_class.new(user, inquiry)

    expect(policy.index?).to be(true)
    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
    expect(policy.reassign_checkout?).to be(true)
    expect(policy.won_deals?).to be(true)
  end

  it "allows sales_manager to view/edit all leads and reassign checkout" do
    user = build_user(:sales_manager)
    policy = described_class.new(user, inquiry)

    expect(policy.index?).to be(true)
    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.reassign_checkout?).to be(true)
    expect(policy.destroy?).to be(false)
  end

  it "allows sales_rep to update only owned leads" do
    user = owner
    policy = described_class.new(user, inquiry)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.reassign_checkout?).to be(false)
  end

  it "allows sales_rep to update only checked-out leads" do
    user = checked_out_rep
    policy = described_class.new(user, inquiry)

    expect(policy.update?).to be(true)
  end

  it "prevents sales_rep from updating other leads" do
    user = build_user(:sales_rep)
    policy = described_class.new(user, inquiry)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(false)
    expect(policy.reassign_checkout?).to be(false)
  end

  it "prevents support from editing leads" do
    user = build_user(:support)
    policy = described_class.new(user, inquiry)

    expect(policy.show?).to be(false)
    expect(policy.update?).to be(false)
  end

  it "allows unauthenticated public lead creation" do
    policy = described_class.new(nil, inquiry)

    expect(policy.public_create?).to be(true)
    expect(policy.create?).to be(false)
  end

end
