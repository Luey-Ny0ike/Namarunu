# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadSubmissionMatcher do
  def create_user
    User.create!(
      email_address: "contributor-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :lead_contributor
    )
  end

  it "attaches to an existing lead on instagram handle match and records activity" do
    user = create_user
    lead = Lead.create!(
      business_name: "Existing Co",
      lead_contacts_attributes: [{ name: "Jane", phone: "+254700000001" }]
    )
    LeadSubmission.create!(
      business_name: "Historic Submission",
      instagram_url: "https://instagram.com/acme.shop",
      submitted_by_user: user,
      lead: lead
    )

    submission = LeadSubmission.new(
      business_name: "Acme",
      instagram_url: "https://www.instagram.com/ACME.SHOP/?hl=en",
      submitted_by_user: user
    )

    expect { described_class.new(submission).call }
      .to change(Activity, :count).by(1)
      .and change(Lead, :count).by(0)

    expect(submission).to be_persisted
    expect(submission.lead).to eq(lead)
    expect(submission.match_outcome).to eq("attached_existing")
    expect(submission.matched_field).to eq("instagram")

    activity = Activity.last
    expect(activity.subject).to eq(lead)
    expect(activity.action_type).to eq("submission_attached")
    expect(activity.metadata).to include(
      "submission_id" => submission.id,
      "matched_field" => "instagram"
    )
  end

  it "attaches to existing lead on phone match using normalized contact phone" do
    user = create_user
    lead = Lead.create!(
      business_name: "Phone Match Co",
      lead_contacts_attributes: [{ name: "Jane", phone: "+254 712 345 678" }]
    )
    submission = LeadSubmission.new(
      business_name: "Phone Input Co",
      phone_raw: "254712345678",
      submitted_by_user: user
    )

    described_class.new(submission).call

    expect(submission.lead).to eq(lead)
    expect(submission.match_outcome).to eq("attached_existing")
    expect(submission.matched_field).to eq("phone")
    expect(Activity.last.action_type).to eq("submission_attached")
    expect(Activity.last.metadata["matched_field"]).to eq("phone")
  end

  it "creates a new contributor lead when no match is found and records activity" do
    user = create_user
    submission = LeadSubmission.new(
      business_name: "Brand New Co",
      location: "Nairobi",
      instagram_url: "https://instagram.com/brandnewco",
      submitted_by_user: user
    )

    expect { described_class.new(submission).call }
      .to change(Lead, :count).by(1)
      .and change(Activity, :count).by(1)

    created_lead = Lead.order(:id).last
    expect(submission).to be_persisted
    expect(submission.lead).to eq(created_lead)
    expect(submission.match_outcome).to eq("created_new")
    expect(submission.matched_field).to be_nil

    expect(created_lead.business_name).to eq("Brand New Co")
    expect(created_lead.location).to eq("Nairobi")
    expect(created_lead.source).to eq("contributor")
    expect(created_lead.owner_user_id).to be_nil
    expect(created_lead.lead_contacts).to be_empty

    activity = Activity.last
    expect(activity.subject).to eq(created_lead)
    expect(activity.action_type).to eq("lead_created_from_submission")
    expect(activity.metadata).to include("submission_id" => submission.id)
  end
end
