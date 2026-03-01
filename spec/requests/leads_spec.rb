# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leads", type: :request do
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

  it "writes activity records for lead create, update, and status change" do
    user = build_user(:sales_rep)
    sign_in_as(user)

    expect do
      post leads_path, params: {
        lead: {
          business_name: "Acme",
          location: "Nairobi",
          industry: "Retail",
          source: "manual",
          lead_contacts_attributes: {
            "0" => { name: "Jane Doe", phone: "+15551234567", preferred_channel: "phone" }
          }
        }
      }
    end.to change(Lead, :count).by(1)
      .and change(Activity, :count).by(1)

    lead = Lead.last
    create_activity = Activity.last
    expect(create_activity.subject).to eq(lead)
    expect(create_activity.actor_user).to eq(user)
    expect(create_activity.action_type).to eq("lead_created")

    expect do
      patch lead_path(lead), params: {
        lead: {
          status: "qualified",
          industry: "Fashion"
        }
      }
    end.to change(Activity, :count).by(2)

    actions = lead.activities.order(:created_at).last(2).map(&:action_type)
    expect(actions).to contain_exactly("lead_updated", "lead_status_changed")
  end

  it "prevents duplicate checkout and shows current holder" do
    owner = build_user(:sales_rep)
    first_rep = build_user(:sales_rep)
    second_rep = build_user(:sales_rep)
    lead = Lead.create!(
      business_name: "Checkout Co",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Primary Contact", phone: "+15551230000" }]
    )

    sign_in_as(first_rep)
    expect do
      patch checkout_lead_path(lead)
    end.to change(LeadAssignment, :count).by(1)
      .and change(Activity, :count).by(1)
    expect(response).to redirect_to(lead_path(lead))
    follow_redirect!
    expect(response.body).to include("Lead checked out")

    sign_in_as(second_rep)
    expect do
      patch checkout_lead_path(lead)
    end.not_to change(LeadAssignment, :count)

    follow_redirect!
    expect(response.body).to include("Already checked out by")
    expect(response.body).to include(first_rep.full_name)
  end

  it "allows manager to force release and reassign checkout" do
    owner = build_user(:sales_rep)
    current_rep = build_user(:sales_rep)
    next_rep = build_user(:sales_rep)
    manager = build_user(:sales_manager)
    lead = Lead.create!(
      business_name: "Manager Co",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Primary Contact", phone: "+15551231111" }]
    )
    LeadAssignment.create!(
      lead: lead,
      user: current_rep,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    sign_in_as(manager)

    expect do
      patch force_release_lead_path(lead)
    end.to change { lead.reload.lead_assignments.unreleased.count }.from(1).to(0)
      .and change(Activity, :count).by(1)
    expect(Activity.last.action_type).to eq("released")

    expect do
      patch reassign_checkout_lead_path(lead), params: { user_id: next_rep.id }
    end.to change { lead.reload.lead_assignments.active_at.count }.from(0).to(1)
      .and change(Activity, :count).by(1)
    expect(Activity.last.action_type).to eq("reassigned")
  end
end
