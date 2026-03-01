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

  it "logs call attempt and automatically transitions status for booked demo outcome" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = Lead.create!(
      business_name: "Pipeline Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Contact", phone: "+15550004444" }]
    )

    expect do
      post log_call_attempt_lead_path(lead), params: {
        call_attempt: {
          outcome: "booked_demo",
          notes: "Booked for Thursday afternoon"
        }
      }
    end.to change(Activity, :count).by(2)

    expect(response).to redirect_to(lead_path(lead))
    lead.reload
    expect(lead.status).to eq("demo_booked")
    expect(lead.last_contacted_at).to be_within(5.seconds).of(Time.current)

    call_activity = lead.activities.order(:created_at).last(2).find { |activity| activity.action_type == "call_attempt_logged" }
    expect(call_activity.metadata).to include("outcome" => "booked_demo", "notes" => "Booked for Thursday afternoon")
  end

  it "requires follow_up date when logging follow_up outcome and shows tasks for reps" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    checked_out_lead = Lead.create!(
      business_name: "Checked Out Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Primary", phone: "+15550005555" }]
    )
    LeadAssignment.create!(
      lead: checked_out_lead,
      user: rep,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    follow_up_due = Lead.create!(
      business_name: "Follow Up Co",
      owner_user: rep,
      next_action_at: 30.minutes.ago,
      lead_contacts_attributes: [{ name: "Due Contact", phone: "+15550006666" }]
    )
    existing_due = Lead.create!(
      business_name: "Due Today Co",
      owner_user: rep,
      next_action_at: 15.minutes.ago,
      lead_contacts_attributes: [{ name: "Today Contact", phone: "+15550008888" }]
    )
    Lead.create!(
      business_name: "Not Due Co",
      owner_user: other_rep,
      next_action_at: 2.days.from_now,
      lead_contacts_attributes: [{ name: "Future Contact", phone: "+15550007777" }]
    )

    post log_call_attempt_lead_path(follow_up_due), params: { call_attempt: { outcome: "follow_up", notes: "Call back tomorrow" } }
    expect(response).to redirect_to(lead_path(follow_up_due))
    follow_redirect!
    expect(response.body).to include("Follow-up date is required")

    follow_up_at = 1.day.from_now.change(sec: 0)
    post log_call_attempt_lead_path(follow_up_due), params: {
      call_attempt: {
        outcome: "follow_up",
        notes: "Call back tomorrow",
        follow_up_at: follow_up_at.strftime("%Y-%m-%dT%H:%M")
      }
    }

    follow_up_due.reload
    expect(follow_up_due.status).to eq("contacted")
    expect(follow_up_due.next_action_at).to be_within(1.minute).of(follow_up_at)
    expect(follow_up_due.last_contacted_at).to be_present

    get my_tasks_leads_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Tasks")
    expect(response.body).to include("Checked Out Co")
    expect(response.body).to include(existing_due.business_name)
    expect(response.body).not_to include("Follow Up Co")
    expect(response.body).not_to include("Not Due Co")
  end

  it "books a demo from a lead and writes lead activity" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = Lead.create!(
      business_name: "Demo Lead Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Contact", phone: "+15550009999" }]
    )

    expect do
      post book_demo_lead_path(lead), params: {
        demo: {
          scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"),
          duration_minutes: 45,
          notes: "Tailored walkthrough",
          demo_link: "https://meet.example.com/demo-1"
        }
      }
    end.to change(Demo, :count).by(1)
      .and change(Activity, :count).by(3)

    demo = Demo.last
    expect(response).to redirect_to(demo_path(demo))
    expect(demo.lead).to eq(lead)
    expect(demo.created_by_user).to eq(rep)
    expect(demo.assigned_to_user).to eq(rep)

    lead.reload
    expect(lead.status).to eq("demo_booked")
    expect(lead.activities.order(:created_at).pluck(:action_type)).to include("demo_booked", "lead_status_changed")
  end

  it "shows demo metrics on lead dashboard" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    Demo.create!(scheduled_at: 1.day.ago, duration_minutes: 30, status: :completed, created_by_user: rep, assigned_to_user: rep)
    Demo.create!(scheduled_at: 2.days.ago, duration_minutes: 30, status: :no_show, created_by_user: rep, assigned_to_user: rep)
    Demo.create!(scheduled_at: 1.day.from_now, duration_minutes: 30, status: :scheduled, created_by_user: rep, assigned_to_user: rep)

    get leads_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Demos Booked")
    expect(response.body).to include("3")
    expect(response.body).to include("Demos Completed")
    expect(response.body).to include("1")
    expect(response.body).to include("Show Rate")
    expect(response.body).to include("50.0%")
  end
end
