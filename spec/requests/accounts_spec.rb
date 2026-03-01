# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts", type: :request do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
    expect(response).to have_http_status(:redirect)
  end

  it "shows account contacts and demo history" do
    manager = build_user(:sales_manager)
    rep = build_user(:sales_rep)
    sign_in_as(manager)

    lead = Lead.create!(
      business_name: "Account Source Co",
      owner_user: rep,
      status: :demo_booked,
      lead_contacts_attributes: [{ name: "Lead Contact", phone: "+15558889999" }]
    )
    account = Account.create!(name: "Account Source Co", converted_from_lead: lead)
    Contact.create!(account: account, name: "Primary", phone: "+15557778888", email: "primary@example.com", role: "CEO")
    Demo.create!(
      lead: lead,
      account: account,
      scheduled_at: 1.day.ago,
      duration_minutes: 45,
      status: :completed,
      created_by_user: rep,
      assigned_to_user: rep
    )

    get account_path(account)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Account Source Co")
    expect(response.body).to include("Primary")
    expect(response.body).to include("Demo History")
    expect(response.body).to include("Completed")
  end
end
