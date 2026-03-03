# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::Demos", type: :request do
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

  def create_lead(owner, name: "Lead", status: :demo_booked)
    Lead.create!(
      business_name: name,
      owner_user: owner,
      status: status,
      lead_contacts_attributes: [{ name: "#{name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    )
  end

  it "filters reps to assigned demos and supports Today/Upcoming/Past tabs" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    today_lead = create_lead(rep, name: "Today Lead")
    upcoming_lead = create_lead(rep, name: "Upcoming Lead")
    past_lead = create_lead(rep, name: "Past Lead")
    hidden_lead = create_lead(other_rep, name: "Hidden Lead")

    Demo.create!(lead: today_lead, created_by_user: rep, assigned_to_user: rep, scheduled_at: Time.current.change(hour: 11, min: 0), duration_minutes: 30)
    Demo.create!(lead: upcoming_lead, created_by_user: rep, assigned_to_user: rep, scheduled_at: 2.days.from_now.change(hour: 10, min: 0), duration_minutes: 30)
    Demo.create!(lead: past_lead, created_by_user: rep, assigned_to_user: rep, scheduled_at: 2.days.ago.change(hour: 10, min: 0), duration_minutes: 30)
    Demo.create!(lead: hidden_lead, created_by_user: other_rep, assigned_to_user: other_rep, scheduled_at: Time.current.change(hour: 12, min: 0), duration_minutes: 30)

    get app_demos_path(tab: "today")
    expect(response.body).to include("Today Lead")
    expect(response.body).not_to include("Hidden Lead")

    get app_demos_path(tab: "upcoming")
    expect(response.body).to include("Upcoming Lead")
    expect(response.body).not_to include("Past Lead")

    get app_demos_path(tab: "past")
    expect(response.body).to include("Past Lead")
    expect(response.body).not_to include("Upcoming Lead")
  end

  it "allows manager to view all demos and filter by assigned_to_user_id" do
    manager = build_user(:sales_manager)
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(manager)

    rep_lead = create_lead(rep, name: "Rep Demo")
    other_lead = create_lead(other_rep, name: "Other Demo")
    Demo.create!(lead: rep_lead, created_by_user: rep, assigned_to_user: rep, scheduled_at: Time.current.change(hour: 10, min: 0), duration_minutes: 30)
    Demo.create!(lead: other_lead, created_by_user: other_rep, assigned_to_user: other_rep, scheduled_at: Time.current.change(hour: 13, min: 0), duration_minutes: 30)

    get app_demos_path(tab: "today")
    expect(response.body).to include("Rep Demo", "Other Demo")

    get app_demos_path(tab: "today", assigned_to_user_id: rep.id)
    expect(response.body).to include("Rep Demo")
    expect(response.body).not_to include("Other Demo")
  end

  it "completes demo and sets lead status to demo_completed for completed/no_show" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = create_lead(rep, name: "Complete Lead")
    demo = Demo.create!(
      lead: lead,
      scheduled_at: 1.hour.ago,
      duration_minutes: 30,
      status: :scheduled,
      created_by_user: rep,
      assigned_to_user: rep
    )

    expect do
      post complete_app_demo_path(demo), params: { status: "completed", outcome: "qualified", notes: "Good fit" }
    end.to change { Activity.where(action_type: "demo_completed").count }.by(1)

    expect(response).to redirect_to(app_demos_path(tab: "today"))
    expect(demo.reload.status).to eq("completed")
    expect(demo.outcome).to eq("qualified")
    expect(lead.reload.status).to eq("demo_completed")
  end

  it "renders demo show in app namespace" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = create_lead(rep, name: "Show Demo Lead")
    demo = Demo.create!(
      lead: lead,
      created_by_user: rep,
      assigned_to_user: rep,
      scheduled_at: 2.hours.from_now,
      duration_minutes: 30
    )

    get app_demo_path(demo)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Demo ##{demo.id}")
    expect(response.body).to include("Namarunu CRM")
  end
end
