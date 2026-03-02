# frozen_string_literal: true

require "rails_helper"

RSpec.describe Leads::SmartPull do
  def create_rep
    User.create!(
      email_address: "rep-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
  end

  def create_unassigned_lead!(business_name:, source: "manual", status: :new, created_at: Time.current, lost_reason: nil)
    lead = Lead.create!(
      business_name: business_name,
      source: source,
      status: status,
      lost_reason: lost_reason,
      lead_contacts_attributes: [{ name: "#{business_name} Contact", phone: "+1555#{SecureRandom.random_number(10_000_000..99_999_999)}" }]
    )
    lead.update_column(:created_at, created_at)
    lead
  end

  it "prefers newer contributor leads, then other unassigned leads and excludes ineligible leads" do
    rep = create_rep
    now = Time.current

    contributor_newer = create_unassigned_lead!(
      business_name: "Contributor Newer",
      source: "contributor",
      created_at: now - 1.hour
    )
    contributor_older = create_unassigned_lead!(
      business_name: "Contributor Older",
      source: "contributor",
      created_at: now - 2.hours
    )
    other_newer = create_unassigned_lead!(
      business_name: "Other Newer",
      source: "manual",
      created_at: now - 30.minutes
    )
    other_older = create_unassigned_lead!(
      business_name: "Other Older",
      source: "manual",
      created_at: now - 3.hours
    )

    won = create_unassigned_lead!(business_name: "Won Co", status: :won)
    lost = create_unassigned_lead!(business_name: "Lost Co", status: :lost, source: "contributor", created_at: now, lost_reason: :other)
    owned = Lead.create!(
      business_name: "Owned Co",
      owner_user: rep,
      lead_contacts_attributes: [{ name: "Owned Contact", phone: "+15550000001" }]
    )
    already_checked_out = create_unassigned_lead!(business_name: "Already Checked Out", source: "contributor")
    LeadAssignment.create!(
      lead: already_checked_out,
      user: rep,
      checked_out_at: now,
      expires_at: now + 1.hour
    )

    result = described_class.new(user: rep, count: 4).call

    expect(result[:lead_ids]).to eq([contributor_newer.id, contributor_older.id, other_newer.id, other_older.id])
    expect(result[:lead_ids]).not_to include(won.id, lost.id, owned.id, already_checked_out.id)
  end

  it "avoids leads with recent activity when there are enough non-recent options" do
    rep = create_rep
    now = Time.current

    fresh_contributor = create_unassigned_lead!(business_name: "Fresh Contributor", source: "contributor", created_at: now - 10.minutes)
    fresh_other = create_unassigned_lead!(business_name: "Fresh Other", source: "manual", created_at: now - 5.minutes)
    recent_activity_lead = create_unassigned_lead!(business_name: "Recent Activity Lead", source: "contributor", created_at: now)
    Activity.create!(
      actor_user: rep,
      subject: recent_activity_lead,
      action_type: "lead_updated",
      metadata: {},
      occurred_at: now - 30.minutes
    )

    result = described_class.new(user: rep, count: 2).call

    expect(result[:lead_ids]).to contain_exactly(fresh_contributor.id, fresh_other.id)
    expect(result[:lead_ids]).not_to include(recent_activity_lead.id)
  end

  it "falls back to recent-activity leads when pool is too small" do
    rep = create_rep
    now = Time.current

    fresh_contributor = create_unassigned_lead!(business_name: "Fresh Contributor", source: "contributor", created_at: now - 1.hour)
    recent_activity_lead = create_unassigned_lead!(business_name: "Recent Activity Fallback", source: "manual", created_at: now - 2.hours)
    Activity.create!(
      actor_user: rep,
      subject: recent_activity_lead,
      action_type: "lead_updated",
      metadata: {},
      occurred_at: now - 1.hour
    )

    result = described_class.new(user: rep, count: 2).call

    expect(result[:lead_ids]).to include(fresh_contributor.id, recent_activity_lead.id)
  end

  it "creates lead assignments and checked_out activities for pulled leads" do
    rep = create_rep
    lead_one = create_unassigned_lead!(business_name: "Pull One", source: "contributor")
    lead_two = create_unassigned_lead!(business_name: "Pull Two", source: "manual")

    expect do
      result = described_class.new(user: rep, count: 2).call
      expect(result[:lead_ids]).to match_array([lead_one.id, lead_two.id])
      expect(result[:warning]).to be_nil
    end.to change { LeadAssignment.where(user_id: rep.id).count }.by(2)
      .and change { Activity.where(action_type: "checked_out").count }.by(2)

    assignments = LeadAssignment.where(user_id: rep.id).order(:created_at)
    expect(assignments).to all(have_attributes(checked_out_at: be_present))
    expect(assignments).to all(have_attributes(expires_at: be_present))
  end

  it "returns warning when user already exceeds active assignment threshold but still pulls leads" do
    rep = create_rep
    now = Time.current

    31.times do |idx|
      lead = create_unassigned_lead!(business_name: "Active #{idx}", source: "manual", created_at: now - (idx + 1).minutes)
      LeadAssignment.create!(
        lead: lead,
        user: rep,
        checked_out_at: now - 10.minutes,
        expires_at: now + 1.hour
      )
    end

    pull_target = create_unassigned_lead!(business_name: "Pull Target", source: "contributor", created_at: now)
    result = described_class.new(user: rep, count: 1).call

    expect(result[:lead_ids]).to eq([pull_target.id])
    expect(result[:warning]).to include("31 active leads checked out")
  end

  it "releases stale unreleased assignment before creating a new checkout" do
    rep = create_rep
    other_rep = create_rep
    lead = create_unassigned_lead!(business_name: "Stale Assignment Lead", source: "contributor")
    stale_assignment = LeadAssignment.create!(
      lead: lead,
      user: other_rep,
      checked_out_at: 3.hours.ago,
      expires_at: 1.hour.ago
    )

    result = described_class.new(user: rep, count: 1).call

    expect(result[:lead_ids]).to eq([lead.id])
    expect(stale_assignment.reload.released_at).to be_present
    expect(stale_assignment.release_reason).to eq("expired")

    new_assignment = LeadAssignment.where(lead_id: lead.id, user_id: rep.id).order(:created_at).last
    expect(new_assignment).to be_present
    expect(new_assignment.released_at).to be_nil
  end
end
