# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::LeadActions", type: :request do
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

  def create_owned_lead(user, name: "Lead")
    Lead.create!(
      business_name: name,
      owner_user: user,
      lead_contacts_attributes: [{ name: "#{name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    )
  end

  def create_lead(name: "Lead", status: :new, owner_user: nil)
    attributes = {
      business_name: name,
      status: status,
      owner_user: owner_user,
      lead_contacts_attributes: [{ name: "#{name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    }
    attributes[:invoice_sent_at] = Time.current if status.to_s == "invoice_sent"
    Lead.create!(attributes)
  end

  it "requires next_action_at for follow_up outcome" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Follow Up Lead")
    sign_in_as(rep)

    post log_attempt_app_lead_path(lead), params: {
      outcome: "follow_up",
      return_to: lead_path(lead)
    }

    expect(response).to redirect_to(lead_path(lead))
    follow_redirect!
    expect(response.body).to include("Follow-up date is required")
    expect(lead.reload.status).to eq("new")
  end

  it "updates lead status and writes call_logged activity metadata" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Interested Lead")
    sign_in_as(rep)

    expect do
      post log_attempt_app_lead_path(lead), params: {
        outcome: "interested",
        notes: "qualified conversation",
        return_to: app_work_queue_path(lead_id: lead.id)
      }
    end.to change { Activity.where(action_type: "call_logged").count }.by(1)

    lead.reload
    expect(lead.status).to eq("qualified")
    expect(lead.last_contacted_at).to be_within(5.seconds).of(Time.current)
    activity = Activity.where(subject: lead, action_type: "call_logged").order(:created_at).last
    expect(activity.metadata).to include("outcome" => "interested", "notes_present" => true)
    expect(activity.metadata).not_to have_key("notes")
  end

  it "auto-advances to queue_next_lead_id when present and removes won/lost leads from queue session" do
    rep = build_user(:sales_rep)
    lost_target = create_owned_lead(rep, name: "Wrong Number Lead")
    next_lead = create_owned_lead(rep, name: "Next Lead")
    sign_in_as(rep)

    service = instance_double(Leads::SmartPull, call: { lead_ids: [lost_target.id, next_lead.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    LeadAssignment.create!(lead: lost_target, user: rep, checked_out_at: 2.minutes.ago, expires_at: 1.hour.from_now)
    LeadAssignment.create!(lead: next_lead, user: rep, checked_out_at: 1.minute.ago, expires_at: 1.hour.from_now)
    post pull_app_work_queue_path

    post log_attempt_app_lead_path(lost_target), params: {
      outcome: "wrong_number",
      queue_next_lead_id: next_lead.id,
      return_to: lead_path(lost_target)
    }

    expect(response).to redirect_to(app_work_queue_path(lead_id: next_lead.id))
    expect(lost_target.reload.status).to eq("lost")
    expect(lost_target.lost_reason).to eq("invalid_contact")
    get app_work_queue_path
    expect(response.body).to include("Next Lead")
    expect(response.body).not_to include("Wrong Number Lead")
  end

  it "redirects to return_to when queue_next_lead_id is not provided" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Return Target")
    sign_in_as(rep)

    post log_attempt_app_lead_path(lead), params: {
      outcome: "interested",
      return_to: app_work_queue_path(lead_id: lead.id)
    }

    expect(response).to redirect_to(app_work_queue_path(lead_id: lead.id))
  end

  it "books demo from app lead action and sets lead status to demo_booked" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Book Demo Lead")
    sign_in_as(rep)

    expect do
      post book_demo_app_lead_path(lead), params: {
        scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"),
        duration_minutes: 45,
        notes: "Product walkthrough",
        return_to: app_work_queue_path
      }
    end.to change(Demo, :count).by(1)
      .and change { Activity.where(action_type: "demo_booked").count }.by(1)

    expect(response).to redirect_to(app_demos_path(tab: "upcoming"))
    demo = Demo.last
    expect(demo.lead).to eq(lead)
    expect(demo.assigned_to_user).to eq(rep)
    expect(demo.created_by_user).to eq(rep)
    expect(lead.reload.status).to eq("demo_booked")
  end

  it "marks lead as awaiting_commitment and records status_changed activity" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Awaiting Lead")
    sign_in_as(rep)

    expect do
      post mark_awaiting_commitment_app_lead_path(lead), params: { return_to: lead_path(lead) }
    end.to change { Activity.where(action_type: "status_changed").count }.by(1)

    expect(response).to redirect_to(lead_path(lead))
    expect(lead.reload.status).to eq("awaiting_commitment")
    activity = Activity.where(subject: lead, action_type: "status_changed").order(:created_at).last
    expect(activity.metadata).to include("old" => "new", "new" => "awaiting_commitment")
  end

  it "marks invoice sent using server time and records invoice_sent activity" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Invoice Lead")
    sign_in_as(rep)

    expect do
      post mark_invoice_sent_app_lead_path(lead), params: {
        return_to: lead_path(lead),
        invoice_sent_at: 1.year.ago.iso8601
      }
    end.to change { Activity.where(action_type: "invoice_sent").count }.by(1)

    expect(response).to redirect_to(lead_path(lead))
    lead.reload
    expect(lead.status).to eq("invoice_sent")
    expect(lead.invoice_sent_at).to be_within(5.seconds).of(Time.current)
    activity = Activity.where(subject: lead, action_type: "invoice_sent").order(:created_at).last
    expect(Time.zone.parse(activity.metadata["invoice_sent_at"])).to be_within(5.seconds).of(lead.invoice_sent_at)
  end

  it "requires lost_reason to mark lost" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Missing Lost Reason")
    sign_in_as(rep)

    post mark_lost_app_lead_path(lead), params: { return_to: lead_path(lead) }

    expect(response).to redirect_to(lead_path(lead))
    follow_redirect!
    expect(response.body).to include("Lost reason is required")
    expect(lead.reload.status).to eq("new")
  end

  it "marks lost, records activity, and releases active assignment" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Lost Lead")
    next_lead = create_owned_lead(rep, name: "Queue Next")
    sign_in_as(rep)

    assignment = LeadAssignment.create!(
      lead: lead,
      user: rep,
      checked_out_at: Time.current,
      expires_at: 1.hour.from_now
    )
    service = instance_double(Leads::SmartPull, call: { lead_ids: [lead.id, next_lead.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    post pull_app_work_queue_path

    expect do
      post mark_lost_app_lead_path(lead), params: {
        lost_reason: "competitor",
        queue_next_lead_id: next_lead.id,
        return_to: lead_path(lead)
      }
    end.to change { Activity.where(action_type: "lost").count }.by(1)

    expect(response).to redirect_to(app_work_queue_path(lead_id: next_lead.id))
    expect(lead.reload.status).to eq("lost")
    expect(lead.lost_reason).to eq("competitor")
    expect(assignment.reload.released_at).to be_present
    expect(assignment.release_reason).to eq("lost")
  end

  it "requires demo_completed or later stage to confirm payment" do
    rep = build_user(:sales_rep)
    lead = create_owned_lead(rep, name: "Too Early Lead")
    sign_in_as(rep)

    post confirm_payment_app_lead_path(lead), params: { return_to: lead_path(lead) }

    expect(response).to redirect_to(lead_path(lead))
    follow_redirect!
    expect(response.body).to include("Demo completed or later")
    expect(lead.reload.status).to eq("new")
  end

  it "auto-converts unconverted lead then marks won and records converted/won activities" do
    rep = build_user(:sales_rep)
    lead = create_lead(name: "Auto Convert Won", status: :demo_completed, owner_user: rep)
    sign_in_as(rep)

    expect do
      post confirm_payment_app_lead_path(lead), params: { return_to: lead_path(lead) }
    end.to change(Account, :count).by(1)
      .and change { Activity.where(action_type: "converted").count }.by(1)
      .and change { Activity.where(action_type: "won").count }.by(1)

    expect(response).to redirect_to(lead_path(lead))
    lead.reload
    expect(lead.status).to eq("won")
    expect(lead.converted_account).to be_present
  end

  it "marks already-converted lead as won without duplicate conversion activity" do
    rep = build_user(:sales_rep)
    lead = create_lead(name: "Already Converted Won", status: :invoice_sent, owner_user: rep)
    account = Account.create!(name: "Existing Account", converted_from_lead: lead)
    Contact.create!(account: account, name: "Primary Contact")
    sign_in_as(rep)

    expect do
      post confirm_payment_app_lead_path(lead), params: { return_to: lead_path(lead) }
    end.to change(Account, :count).by(0)
      .and change { Activity.where(action_type: "converted").count }.by(0)
      .and change { Activity.where(action_type: "won").count }.by(1)

    expect(lead.reload.status).to eq("won")
  end

  it "supports queue next redirect for confirm payment" do
    rep = build_user(:sales_rep)
    first = create_lead(name: "Queue Won", status: :demo_completed, owner_user: rep)
    second = create_lead(name: "Queue Next Won", status: :demo_completed, owner_user: rep)
    sign_in_as(rep)

    post confirm_payment_app_lead_path(first), params: {
      queue_next_lead_id: second.id,
      return_to: lead_path(first)
    }

    expect(response).to redirect_to(app_work_queue_path(lead_id: second.id))
  end

  it "prevents sales reps from confirming payment on leads they do not own or check out" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    lead = create_lead(name: "Other Rep Lead", status: :demo_completed, owner_user: other_rep)
    sign_in_as(rep)

    post confirm_payment_app_lead_path(lead), params: { return_to: lead_path(lead) }

    expect(response).to redirect_to(root_path)
    expect(lead.reload.status).to eq("demo_completed")
  end

  it "releases lead from queue and redirects to next available lead" do
    rep = build_user(:sales_rep)
    first = create_lead(name: "Release First", owner_user: rep)
    second = create_lead(name: "Release Next", owner_user: rep)
    sign_in_as(rep)

    first_assignment = LeadAssignment.create!(
      lead: first,
      user: rep,
      checked_out_at: Time.current,
      expires_at: 1.hour.from_now
    )
    LeadAssignment.create!(
      lead: second,
      user: rep,
      checked_out_at: Time.current,
      expires_at: 1.hour.from_now
    )
    service = instance_double(Leads::SmartPull, call: { lead_ids: [first.id, second.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    post pull_app_work_queue_path

    post release_and_next_app_lead_path(first), params: {
      queue_next_lead_id: second.id,
      return_to: app_work_queue_path(lead_id: first.id)
    }

    expect(response).to redirect_to(app_work_queue_path(lead_id: second.id))
    expect(first_assignment.reload.released_at).to be_present
    expect(first_assignment.release_reason).to eq("released")
  end

  it "redirects to app with Queue complete when releasing the last queued lead" do
    rep = build_user(:sales_rep)
    lead = create_lead(name: "Final Queue Lead", owner_user: rep)
    sign_in_as(rep)

    assignment = LeadAssignment.create!(
      lead: lead,
      user: rep,
      checked_out_at: Time.current,
      expires_at: 1.hour.from_now
    )
    service = instance_double(Leads::SmartPull, call: { lead_ids: [lead.id], warning: nil })
    allow(Leads::SmartPull).to receive(:new).and_return(service)
    post pull_app_work_queue_path

    post release_and_next_app_lead_path(lead), params: { return_to: app_work_queue_path(lead_id: lead.id) }

    expect(response).to redirect_to(app_root_path)
    expect(assignment.reload.released_at).to be_present
  end
end
