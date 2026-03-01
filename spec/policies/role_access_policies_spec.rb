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

  it "allows support to view accounts but not update them" do
    support_user = build_user(:support)
    account = Account.new(name: "Support Visible")

    expect(AccountPolicy.new(support_user, account).show?).to be(true)
    expect(AccountPolicy.new(support_user, account).update?).to be(false)
  end

  it "allows reps to manage only their own demos and managers all demos" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    manager = build_user(:sales_manager)
    lead = Lead.create!(
      business_name: "Policy Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Contact", phone: "+15551230000" }]
    )
    own_demo = Demo.new(lead: lead, scheduled_at: 1.day.from_now, duration_minutes: 30, created_by_user: rep, assigned_to_user: rep)
    other_demo = Demo.new(lead: lead, scheduled_at: 1.day.from_now, duration_minutes: 30, created_by_user: other_rep, assigned_to_user: other_rep)

    expect(DemoPolicy.new(rep, own_demo).show?).to be(true)
    expect(DemoPolicy.new(rep, other_demo).show?).to be(false)
    expect(DemoPolicy.new(manager, other_demo).update?).to be(true)
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

  it "does not allow lead_contributor to access internal CRM policies" do
    contributor = build_user(:lead_contributor)
    inquiry = Inquiry.new
    lead = Lead.new

    expect(InquiryPolicy.new(contributor, inquiry).index?).to be(false)
    expect(LeadPolicy.new(contributor, lead).index?).to be(false)
  end
end
