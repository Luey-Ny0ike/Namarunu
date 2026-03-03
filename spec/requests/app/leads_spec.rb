# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::Leads", type: :request do
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

  def create_lead(name:, owner: nil, next_action_at: nil)
    Lead.create!(
      business_name: name,
      owner_user: owner,
      next_action_at: next_action_at,
      lead_contacts_attributes: [{ name: "#{name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    )
  end

  it "defaults reps to my + unassigned leads when no tab is provided" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    create_lead(name: "My Lead", owner: rep)
    create_lead(name: "Unassigned Lead", owner: nil)
    create_lead(name: "Other Rep Lead", owner: other_rep)

    get app_leads_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Lead")
    expect(response.body).to include("Unassigned Lead")
    expect(response.body).not_to include("Other Rep Lead")
    expect(response.body).not_to include(">All<")
  end

  it "defaults managers to all leads and shows the All tab" do
    manager = build_user(:sales_manager)
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(manager)

    create_lead(name: "Manager Owned", owner: manager)
    create_lead(name: "Rep Owned", owner: rep)
    create_lead(name: "Other Rep Owned", owner: other_rep)
    create_lead(name: "Unassigned Lead", owner: nil)

    get app_leads_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manager Owned")
    expect(response.body).to include("Rep Owned")
    expect(response.body).to include("Other Rep Owned")
    expect(response.body).to include("Unassigned Lead")
    expect(response.body).to include(">All<")
  end

  it "does not allow reps to use the all tab" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    create_lead(name: "My Lead", owner: rep)
    create_lead(name: "Other Rep Lead", owner: other_rep)

    get app_leads_path(tab: "all")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Lead")
    expect(response.body).not_to include("Other Rep Lead")
  end

  it "redirects legacy /leads index path to /app/leads" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get "/leads"

    expect(response).to redirect_to(app_leads_path)
  end
end
