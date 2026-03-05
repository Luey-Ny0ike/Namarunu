# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::DemosUpdate", type: :request do
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

  it "lets reps update their own demo and marks lead as demo_completed" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = Lead.create!(
      business_name: "Demo Outcome Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Primary", phone: "+15552223333" }],
      status: :demo_booked
    )
    demo = Demo.create!(
      lead: lead,
      scheduled_at: 1.hour.ago,
      duration_minutes: 30,
      status: :scheduled,
      created_by_user: rep,
      assigned_to_user: rep
    )

    expect do
      patch app_demo_path(demo), params: { demo: { status: :completed, outcome: :qualified, notes: "Good fit" } }
    end.to change(Activity, :count).by(3)

    expect(response).to redirect_to(app_demo_path(demo))
    demo.reload
    lead.reload

    expect(demo.status).to eq("completed")
    expect(demo.outcome).to eq("qualified")
    expect(demo.notes).to eq("Good fit")
    expect(lead.status).to eq("demo_completed")
  end

  it "prevents reps from updating demos they do not own" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    demo = Demo.create!(
      scheduled_at: 1.hour.from_now,
      duration_minutes: 30,
      created_by_user: other_rep,
      assigned_to_user: other_rep
    )

    patch app_demo_path(demo), params: { demo: { status: :no_show } }

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(demo.reload.status).to eq("scheduled")
  end

  it "allows managers to manage any demo" do
    manager = build_user(:sales_manager)
    rep = build_user(:sales_rep)
    sign_in_as(manager)

    demo = Demo.create!(
      scheduled_at: 1.hour.from_now,
      duration_minutes: 30,
      created_by_user: rep,
      assigned_to_user: rep
    )

    patch app_demo_path(demo), params: { demo: { status: :no_show, notes: "Customer did not join" } }

    expect(response).to redirect_to(app_demo_path(demo))
    expect(demo.reload.status).to eq("no_show")
  end
end
