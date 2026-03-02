# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::Dashboard", type: :request do
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

  it "allows sales_rep and sales_manager to view /app" do
    rep = build_user(:sales_rep)
    manager = build_user(:sales_manager)

    sign_in_as(rep)
    get app_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Day")
    expect(response.body).to include("Pull 10 Leads")

    sign_in_as(manager)
    get app_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Day")
  end

  it "blocks lead_contributor from /app" do
    contributor = build_user(:lead_contributor)
    sign_in_as(contributor)

    get app_root_path

    expect(response).to redirect_to(contribute_root_path)
  end

  it "shows continue queue only when rep has active checked-out leads" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get app_root_path
    expect(response.body).not_to include("Continue Queue")

    lead = Lead.create!(
      business_name: "Queue Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Queue Contact", phone: "+15551110001" }]
    )
    LeadAssignment.create!(
      lead: lead,
      user: rep,
      checked_out_at: 5.minutes.ago,
      expires_at: 1.hour.from_now
    )

    get app_root_path
    expect(response.body).to include("Continue Queue")
  end

  it "renders todays demos, follow-ups due today, and active leads with quick actions" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    assigned_lead = Lead.create!(
      business_name: "Assigned Demo Lead",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Assigned Contact", phone: "+15551110002" }]
    )
    created_lead = Lead.create!(
      business_name: "Created Demo Lead",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Created Contact", phone: "+15551110003" }]
    )

    Demo.create!(
      lead: assigned_lead,
      assigned_to_user: rep,
      created_by_user: other_rep,
      scheduled_at: Time.current.change(hour: 11, min: 0),
      duration_minutes: 30
    )
    Demo.create!(
      lead: created_lead,
      created_by_user: rep,
      scheduled_at: Time.current.change(hour: 14, min: 0),
      duration_minutes: 30
    )

    checked_out_lead = Lead.create!(
      business_name: "Checked Out Due Lead",
      next_action_at: 30.minutes.from_now,
      lead_contacts_attributes: [{ name: "Due Contact", phone: "+15551110004" }]
    )
    LeadAssignment.create!(
      lead: checked_out_lead,
      user: rep,
      checked_out_at: 10.minutes.ago,
      expires_at: 1.hour.from_now
    )

    owned_due_lead = Lead.create!(
      business_name: "Owned Due Lead",
      owner_user: rep,
      next_action_at: 1.hour.from_now,
      lead_contacts_attributes: [{ name: "Owned Due Contact", phone: "+15551110005" }]
    )

    Activity.create!(
      actor_user: rep,
      subject: owned_due_lead,
      action_type: "lead_updated",
      metadata: {},
      occurred_at: Time.current
    )

    get app_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Today's Demos")
    expect(response.body).to include("Assigned Demo Lead")
    expect(response.body).to include("Created Demo Lead")
    expect(response.body).to include("Follow-ups Due Today")
    expect(response.body).to include("Checked Out Due Lead")
    expect(response.body).to include("Owned Due Lead")
    expect(response.body).to include("My Active Leads")
    expect(response.body).to include("Last activity")
    expect(response.body.scan("Log attempt").size).to be >= 2
    expect(response.body).to include("logCallAttemptModal")
  end
end
