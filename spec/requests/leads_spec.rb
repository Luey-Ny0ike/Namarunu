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
end
