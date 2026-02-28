# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Role-based auxiliary policies" do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  it "allows support to view converted accounts only" do
    support_user = build_user(:support)
    converted = Account.new(converted: true)
    not_converted = Account.new(converted: false)

    expect(AccountPolicy.new(support_user, converted).show?).to be(true)
    expect(AccountPolicy.new(support_user, not_converted).show?).to be(false)
    expect(AccountPolicy.new(support_user, converted).update?).to be(false)
  end

  it "allows support to view demos related to converted accounts only" do
    support_user = build_user(:support)
    converted_account = Account.new(converted: true)
    open_account = Account.new(converted: false)

    expect(DemoPolicy.new(support_user, Demo.new(account: converted_account)).show?).to be(true)
    expect(DemoPolicy.new(support_user, Demo.new(account: open_account)).show?).to be(false)
  end

  it "allows sales_manager to manage activities" do
    manager = build_user(:sales_manager)
    activity = Activity.new
    policy = ActivityPolicy.new(manager, activity)

    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "allows finance to access payout pages" do
    finance_user = build_user(:finance)

    expect(Finance::PayoutPolicy.new(finance_user, :payout).index?).to be(true)
  end

  it "limits admin user management to super_admin" do
    super_admin = build_user(:super_admin)
    manager = build_user(:sales_manager)
    target = build_user(:sales_rep)

    expect(Admin::UserPolicy.new(super_admin, target).update?).to be(true)
    expect(Admin::UserPolicy.new(manager, target).update?).to be(false)
  end
end
