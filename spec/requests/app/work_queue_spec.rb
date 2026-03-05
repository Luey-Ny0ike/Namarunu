# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::WorkQueue", type: :request do
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

  def create_lead(name)
    Lead.create!(
      business_name: name,
      lead_contacts_attributes: [{ name: "#{name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    )
  end

  it "pulls 10 leads using SmartPull and redirects into queue" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead_one = create_lead("Queue One")
    lead_two = create_lead("Queue Two")
    LeadAssignment.create!(lead: lead_one, user: rep, checked_out_at: Time.current, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: lead_two, user: rep, checked_out_at: Time.current, expires_at: 1.hour.from_now)
    service = instance_double(Leads::SmartPull, call: { lead_ids: [lead_one.id, lead_two.id], warning: nil })

    expect(Leads::SmartPull).to receive(:new).with(user: rep, count: 10).and_return(service)

    post pull_app_work_queue_path

    expect(response).to redirect_to(app_work_queue_path(lead_id: lead_one.id))
    follow_redirect!
    expect(response.body).to include("Work Queue (2)")
    expect(response.body).to include("Queue One")
  end

  it "shows warning from SmartPull without blocking pull" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = create_lead("Warning Lead")
    LeadAssignment.create!(lead: lead, user: rep, checked_out_at: Time.current, expires_at: 1.hour.from_now)
    warning = "You currently have 35 active leads checked out."
    service = instance_double(Leads::SmartPull, call: { lead_ids: [lead.id], warning: warning })

    allow(Leads::SmartPull).to receive(:new).and_return(service)

    post pull_app_work_queue_path
    follow_redirect!

    expect(response.body).to include(warning)
    expect(response.body).to include("Warning Lead")
  end

  it "falls back to active assignments when queue session is empty" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    older = create_lead("Older Assignment")
    newer = create_lead("Newer Assignment")
    LeadAssignment.create!(
      lead: older,
      user: rep,
      checked_out_at: 40.minutes.ago,
      expires_at: 1.hour.from_now
    )
    LeadAssignment.create!(
      lead: newer,
      user: rep,
      checked_out_at: 10.minutes.ago,
      expires_at: 1.hour.from_now
    )

    get app_work_queue_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Work Queue (2)")
    expect(response.body).to include("Newer Assignment")
  end

  it "supports prev/next navigation across queued lead IDs" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead_one = create_lead("Nav One")
    lead_two = create_lead("Nav Two")
    lead_three = create_lead("Nav Three")
    LeadAssignment.create!(lead: lead_one, user: rep, checked_out_at: 3.minutes.ago, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: lead_two, user: rep, checked_out_at: 2.minutes.ago, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: lead_three, user: rep, checked_out_at: 1.minute.ago, expires_at: 1.hour.from_now)
    service = instance_double(Leads::SmartPull, call: { lead_ids: [lead_one.id, lead_two.id, lead_three.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)

    post pull_app_work_queue_path
    get app_work_queue_path(lead_id: lead_two.id)

    expect(response.body).to include("Work Queue (3)")
    expect(response.body).to include("Nav Two")
    expect(response.body).to include(app_work_queue_path(lead_id: lead_one.id))
    expect(response.body).to include(app_work_queue_path(lead_id: lead_three.id))
  end

  it "shows the latest call_logged outcome in Last outcome" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = create_lead("Outcome Lead")
    LeadAssignment.create!(lead: lead, user: rep, checked_out_at: Time.current, expires_at: 1.hour.from_now)

    Activity.create!(
      actor_user: rep,
      subject: lead,
      action_type: "call_logged",
      metadata: { outcome: "interested" },
      occurred_at: 2.hours.ago
    )
    Activity.create!(
      actor_user: rep,
      subject: lead,
      action_type: "call_logged",
      metadata: { outcome: "no_answer" },
      occurred_at: 1.hour.ago
    )

    get app_work_queue_path(lead_id: lead.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No answer")
  end

  it "filters queue ids to active assignments for current rep and removes won/lost while preserving order" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    valid_first = create_lead("Valid First")
    won = create_lead("Won Lead")
    valid_second = create_lead("Valid Second")
    released = create_lead("Released Lead")
    won.update!(status: :won)

    LeadAssignment.create!(lead: valid_first, user: rep, checked_out_at: 4.minutes.ago, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: valid_second, user: rep, checked_out_at: 3.minutes.ago, expires_at: 1.hour.from_now)
    released_assignment = LeadAssignment.create!(lead: released, user: rep, checked_out_at: 2.minutes.ago, expires_at: 1.hour.from_now)
    released_assignment.release!(reason: "released", at: Time.current)

    service = instance_double(Leads::SmartPull, call: { lead_ids: [valid_first.id, won.id, valid_second.id, released.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    post pull_app_work_queue_path

    get app_work_queue_path(lead_id: won.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Work Queue (2)")
    expect(response.body).to include("Valid First")
    expect(response.body).not_to include("Won Lead")
    expect(response.body).not_to include("Released Lead")
    expect(response.body).to include(app_work_queue_path(lead_id: valid_second.id))
  end

  it "redirects to app with Queue complete when no valid queue leads remain" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    closed = create_lead("Closed Lead")
    closed.update!(status: :lost, lost_reason: :other)
    LeadAssignment.create!(lead: closed, user: rep, checked_out_at: 5.minutes.ago, expires_at: 1.hour.from_now)
    service = instance_double(Leads::SmartPull, call: { lead_ids: [closed.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    post pull_app_work_queue_path

    get app_work_queue_path

    expect(response).to redirect_to(app_root_path)
    follow_redirect!
    expect(response.body).to include("Queue complete")
  end

  it "blocks lead_contributor from app work queue" do
    contributor = build_user(:lead_contributor)
    sign_in_as(contributor)

    get app_work_queue_path

    expect(response).to redirect_to(contribute_root_path)
  end

  it "blocks support from work queue via lead policy authorization" do
    support = build_user(:support)
    sign_in_as(support)

    get app_work_queue_path

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("You are not authorized to perform this action.")
  end

  it "respects policy_scope changes when loading queue leads" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)
    lead = create_lead("Scoped Queue Lead")
    LeadAssignment.create!(lead: lead, user: rep, checked_out_at: Time.current, expires_at: 1.hour.from_now)

    allow_any_instance_of(App::WorkQueueController).to receive(:policy_scope).with(Lead).and_return(Lead.none)

    get app_work_queue_path

    expect(response).to redirect_to(app_root_path)
  end
end
