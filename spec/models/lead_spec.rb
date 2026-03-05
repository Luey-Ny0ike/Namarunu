# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lead, type: :model do
  it "requires at least one lead contact" do
    lead = described_class.new(business_name: "Acme")

    expect(lead).not_to be_valid
    expect(lead.errors[:lead_contacts]).to include("must include at least one contact")
  end

  it "is valid with one contact" do
    lead = described_class.new(
      business_name: "Acme",
      lead_contacts_attributes: [{ name: "Jane Doe", email: "jane@example.com" }]
    )

    expect(lead).to be_valid
  end

  it "allows zero contacts when source is contributor" do
    lead = described_class.new(
      business_name: "Contributor Lead",
      source: "contributor"
    )

    expect(lead).to be_valid
  end

  it "normalizes handles and generates canonical social urls" do
    lead = described_class.new(
      business_name: "Social Co",
      source: "contributor",
      instagram_handle: "  @Acme.Shop  ",
      tiktok_handle: " @AcmeTok ",
      facebook_url: "  www.facebook.com/acme  "
    )

    expect(lead).to be_valid
    expect(lead.instagram_handle).to eq("acme.shop")
    expect(lead.tiktok_handle).to eq("acmetok")
    expect(lead.facebook_url).to eq("https://www.facebook.com/acme")
    expect(lead.instagram_url).to eq("https://www.instagram.com/acme.shop/")
    expect(lead.tiktok_url).to eq("https://www.tiktok.com/@acmetok")
  end

  it "regenerates canonical urls when social handles change" do
    lead = described_class.create!(
      business_name: "Regenerate Co",
      source: "contributor",
      instagram_handle: "oldname",
      tiktok_handle: "oldtok"
    )

    lead.update!(
      instagram_handle: "New.Name",
      tiktok_handle: "@NewTok"
    )

    expect(lead.instagram_handle).to eq("new.name")
    expect(lead.tiktok_handle).to eq("newtok")
    expect(lead.instagram_url).to eq("https://www.instagram.com/new.name/")
    expect(lead.tiktok_url).to eq("https://www.tiktok.com/@newtok")
  end

  it "allows blank social urls when handles are blank" do
    lead = described_class.new(
      business_name: "Blank Socials Co",
      source: "contributor",
      instagram_handle: " ",
      tiktok_handle: nil,
      instagram_url: nil,
      tiktok_url: nil
    )

    expect(lead).to be_valid
    expect(lead.instagram_url).to be_nil
    expect(lead.tiktok_url).to be_nil
  end

  it "rejects invalid handle and non-http url formats" do
    lead = described_class.new(
      business_name: "Invalid Social Co",
      source: "contributor",
      instagram_handle: "bad handle",
      instagram_url: "instagram.com/bad",
      tiktok_url: "ftp://tiktok.com/@bad"
    )

    expect(lead).not_to be_valid
    expect(lead.errors[:instagram_handle]).to be_present
    expect(lead.errors[:instagram_url]).to be_present
    expect(lead.errors[:tiktok_url]).to be_present
  end

  it "requires lost_reason when status is lost" do
    lead = described_class.new(
      business_name: "Lost Co",
      status: :lost,
      lead_contacts_attributes: [{ name: "Lost Contact", phone: "+15550001112" }]
    )

    expect(lead).not_to be_valid
    expect(lead.errors[:lost_reason]).to include("can't be blank")
  end

  it "requires invoice_sent_at when status is invoice_sent" do
    lead = described_class.new(
      business_name: "Invoice Co",
      status: :invoice_sent,
      lead_contacts_attributes: [{ name: "Invoice Contact", phone: "+15550001113" }]
    )

    expect(lead).not_to be_valid
    expect(lead.errors[:invoice_sent_at]).to include("can't be blank")
  end

  it "accepts awaiting_commitment and invoice_sent statuses" do
    awaiting = described_class.new(
      business_name: "Awaiting Co",
      status: :awaiting_commitment,
      lead_contacts_attributes: [{ name: "Awaiting Contact", phone: "+15550001114" }]
    )
    invoiced = described_class.new(
      business_name: "Invoiced Co",
      status: :invoice_sent,
      invoice_sent_at: Time.current,
      lead_contacts_attributes: [{ name: "Invoiced Contact", phone: "+15550001115" }]
    )

    expect(awaiting).to be_valid
    expect(invoiced).to be_valid
  end

  it "returns only due follow-ups" do
    due = described_class.create!(
      business_name: "Due Co",
      next_action_at: 1.hour.ago,
      lead_contacts_attributes: [{ name: "Due Contact", phone: "+15550001111" }]
    )
    described_class.create!(
      business_name: "Later Co",
      next_action_at: 1.day.from_now,
      lead_contacts_attributes: [{ name: "Later Contact", phone: "+15550002222" }]
    )

    expect(described_class.follow_ups_due).to contain_exactly(due)
  end

  it "allows owner or active assignee to edit" do
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    assignee = User.create!(
      email_address: "assignee-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    other = User.create!(
      email_address: "other-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Editable Co",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Lead Contact", phone: "+15550003333" }]
    )
    LeadAssignment.create!(
      lead: lead,
      user: assignee,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    expect(lead.editable_by?(owner)).to be(true)
    expect(lead.editable_by?(assignee)).to be(true)
    expect(lead.editable_by?(other)).to be(false)
  end

  it "maps call outcomes to pipeline statuses" do
    expect(described_class.call_outcome_status_transition("booked_demo")).to eq("demo_booked")
    expect(described_class.call_outcome_status_transition("interested")).to eq("qualified")
    expect(described_class.call_outcome_status_transition("unknown")).to be_nil
  end

  it "returns contributor progress stage as Won when status is won" do
    lead = described_class.create!(
      business_name: "Won Co",
      status: :won,
      lead_contacts_attributes: [{ name: "Won Contact", phone: "+15550004444" }]
    )

    expect(lead.contributor_progress_stage).to eq("Won")
  end

  it "returns contributor progress stage as Lost when status is lost" do
    lead = described_class.create!(
      business_name: "Lost Co",
      status: :lost,
      lost_reason: :not_a_fit,
      lead_contacts_attributes: [{ name: "Lost Contact", phone: "+15550005555" }]
    )

    expect(lead.contributor_progress_stage).to eq("Lost")
  end

  it "returns Demo done when lead status is demo_completed" do
    lead = described_class.create!(
      business_name: "Done Co",
      status: :demo_completed,
      lead_contacts_attributes: [{ name: "Done Contact", phone: "+15550006666" }]
    )

    expect(lead.contributor_progress_stage).to eq("Demo done")
  end

  it "returns Demo done when a demo is completed or no_show" do
    creator = User.create!(
      email_address: "demo-creator-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Demo Evidence Co",
      status: :in_progress,
      lead_contacts_attributes: [{ name: "Demo Contact", phone: "+15550007777" }]
    )
    Demo.create!(
      lead: lead,
      created_by_user: creator,
      scheduled_at: 1.day.ago,
      duration_minutes: 30,
      status: :no_show
    )

    expect(lead.contributor_progress_stage).to eq("Demo done")
  end

  it "returns Demo booked when status is demo_booked or scheduled demo exists" do
    creator = User.create!(
      email_address: "demo-booked-creator-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Booked Co",
      status: :contacted,
      lead_contacts_attributes: [{ name: "Booked Contact", phone: "+15550008888" }]
    )
    Demo.create!(
      lead: lead,
      created_by_user: creator,
      scheduled_at: 1.day.from_now,
      duration_minutes: 30,
      status: :scheduled
    )

    expect(lead.contributor_progress_stage).to eq("Demo booked")
  end

  it "returns Contacted for contacted or qualified when no demo stage applies" do
    contacted = described_class.create!(
      business_name: "Contacted Co",
      status: :contacted,
      lead_contacts_attributes: [{ name: "Contacted", phone: "+15550009991" }]
    )
    qualified = described_class.create!(
      business_name: "Qualified Co",
      status: :qualified,
      lead_contacts_attributes: [{ name: "Qualified", phone: "+15550009992" }]
    )

    expect(contacted.contributor_progress_stage).to eq("Contacted")
    expect(qualified.contributor_progress_stage).to eq("Contacted")
  end

  it "returns New when none of the contributor progress conditions apply" do
    lead = described_class.create!(
      business_name: "New Co",
      status: :new,
      lead_contacts_attributes: [{ name: "New Contact", phone: "+15550001010" }]
    )

    expect(lead.contributor_progress_stage).to eq("New")
  end

  it "prefers active assignment user over owner for contributor assigned rep" do
    owner = User.create!(
      email_address: "rep-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    assignee = User.create!(
      email_address: "rep-assignee-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Assigned Co",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Assigned Contact", phone: "+15550002020" }]
    )
    LeadAssignment.create!(
      lead: lead,
      user: assignee,
      checked_out_at: Time.current,
      expires_at: 2.hours.from_now
    )

    expect(lead.contributor_assigned_rep).to eq(assignee)
  end

  it "falls back to owner user when no active assignment exists" do
    owner = User.create!(
      email_address: "rep-fallback-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Owner Fallback Co",
      owner_user: owner,
      lead_contacts_attributes: [{ name: "Owner Contact", phone: "+15550003030" }]
    )

    expect(lead.contributor_assigned_rep).to eq(owner)
  end

  it "returns nil assigned rep when neither assignment nor owner exists" do
    lead = described_class.create!(
      business_name: "No Rep Co",
      lead_contacts_attributes: [{ name: "No Rep Contact", phone: "+15550004040" }]
    )

    expect(lead.contributor_assigned_rep).to be_nil
  end

  it "returns a sanitized contributor timeline with restricted event types only" do
    rep = User.create!(
      email_address: "timeline-rep-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: "Timeline Rep",
      role: :sales_rep
    )
    creator = User.create!(
      email_address: "timeline-demo-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :sales_rep
    )
    lead = described_class.create!(
      business_name: "Timeline Co",
      lead_contacts_attributes: [{ name: "Timeline Contact", phone: "+15550005050" }]
    )

    Activity.create!(
      actor_user: rep,
      subject: lead,
      action_type: "lead_updated",
      metadata: { notes: "internal-only note" },
      occurred_at: 5.hours.ago
    )
    Activity.create!(
      actor_user: rep,
      subject: lead,
      action_type: "call_attempt_logged",
      metadata: { outcome: "no_answer", notes: "secret rep notes" },
      occurred_at: 4.hours.ago
    )
    Activity.create!(
      actor_user: rep,
      subject: lead,
      action_type: "lead_status_changed",
      metadata: { from: "new", to: "qualified", notes: "do not expose" },
      occurred_at: 3.hours.ago
    )
    Activity.create!(
      actor_user: rep,
      subject: lead,
      action_type: "converted",
      metadata: { private_reason: "internal" },
      occurred_at: 2.hours.ago
    )
    Demo.create!(
      lead: lead,
      created_by_user: creator,
      assigned_to_user: rep,
      scheduled_at: 1.day.ago,
      duration_minutes: 30,
      status: :completed
    )

    timeline = lead.contributor_timeline
    labels = timeline.map { |event| event[:label] }

    expect(labels).to include("Call logged (No answer)")
    expect(labels).to include("Status changed: New -> Qualified")
    expect(labels).to include("Lead won")
    expect(labels).to include("Demo done")
    expect(labels).not_to include("Lead updated")
    expect(labels.join(" ")).not_to include("secret")
    expect(labels.join(" ")).not_to include("internal-only")
    expect(timeline.first).to include(:label, :occurred_at)
  end
end
