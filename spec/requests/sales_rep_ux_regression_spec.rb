# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sales rep UX regressions", type: :request do
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

  def create_lead(name:, source: "manual", status: :new, owner_user: nil)
    attrs = {
      business_name: name,
      source: source,
      status: status,
      owner_user: owner_user,
      lead_contacts_attributes: [{ name: "#{name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    }
    attrs[:invoice_sent_at] = Time.current if status.to_s == "invoice_sent"
    attrs[:lost_reason] = :other if status.to_s == "lost"
    Lead.create!(attrs)
  end

  it "shows pull and continue queue on /app for reps with active assignments" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get app_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pull 10 Leads")
    expect(response.body).not_to include("Continue Queue")

    lead = create_lead(name: "Active Queue Lead")
    LeadAssignment.create!(
      lead: lead,
      user: rep,
      checked_out_at: Time.current,
      expires_at: 1.hour.from_now
    )

    get app_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Continue Queue")
  end

  it "smart pull creates assignments and redirects to work queue" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    create_lead(name: "Pull Candidate 1", source: "contributor")
    create_lead(name: "Pull Candidate 2", source: "manual")

    expect do
      post pull_app_work_queue_path
    end.to change { LeadAssignment.where(user_id: rep.id).active_at.count }.by(2)

    expect(response).to redirect_to(/\/app\/work_queue\?lead_id=\d+/)
    follow_redirect!
    expect(response.body).to include("Work Queue (2)")
  end

  it "shows one lead at a time, supports prev/next, and advances/removes on lost and won closes" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lost_target = create_lead(name: "Lost Target")
    won_target = create_lead(name: "Won Target", status: :demo_completed)
    tail = create_lead(name: "Tail Lead")
    LeadAssignment.create!(lead: lost_target, user: rep, checked_out_at: 3.minutes.ago, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: won_target, user: rep, checked_out_at: 2.minutes.ago, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: tail, user: rep, checked_out_at: 1.minute.ago, expires_at: 1.hour.from_now)

    service = instance_double(Leads::SmartPull, call: { lead_ids: [lost_target.id, won_target.id, tail.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    post pull_app_work_queue_path

    get app_work_queue_path(lead_id: lost_target.id)
    expect(response.body).to include("Lost Target")
    expect(response.body).not_to include("Won Target")
    expect(response.body).to include(app_work_queue_path(lead_id: won_target.id))

    post log_attempt_app_lead_path(lost_target), params: {
      outcome: "wrong_number",
      queue_next_lead_id: won_target.id,
      return_to: app_work_queue_path(lead_id: lost_target.id)
    }
    expect(response).to redirect_to(app_work_queue_path(lead_id: won_target.id))
    expect(lost_target.reload.status).to eq("lost")

    post confirm_payment_app_lead_path(won_target), params: {
      queue_next_lead_id: tail.id,
      return_to: app_work_queue_path(lead_id: won_target.id)
    }
    expect(response).to redirect_to(app_work_queue_path(lead_id: tail.id))
    expect(won_target.reload.status).to eq("won")

    get app_work_queue_path
    expect(response.body).to include("Tail Lead")
    expect(response.body).not_to include("Lost Target")
    expect(response.body).not_to include("Won Target")
  end

  it "keeps marketing navbar free of CRM links when authenticated" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("marketing-navbar")
    expect(response.body).not_to include("Leads")
    expect(response.body).not_to include("Won Deals")
    expect(response.body).not_to include("Payouts")
    expect(response.body).not_to include("Manage Users")
  end
end
