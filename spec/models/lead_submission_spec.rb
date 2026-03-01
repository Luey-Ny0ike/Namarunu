# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadSubmission, type: :model do
  def build_submission(attributes = {})
    user = User.create!(
      email_address: "contributor-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :lead_contributor
    )

    described_class.new(
      business_name: "Acme Co",
      submitted_by_user: user,
      instagram_url: "https://instagram.com/acmeco",
      **attributes
    )
  end

  it "requires business_name" do
    submission = build_submission(business_name: " ")

    expect(submission).not_to be_valid
    expect(submission.errors[:business_name]).to include("can't be blank")
  end

  it "requires at least one identifier" do
    submission = build_submission(instagram_url: nil, tiktok_url: nil, phone_raw: nil)

    expect(submission).not_to be_valid
    expect(submission.errors[:base]).to include("must include at least one identifier")
  end

  it "extracts and normalizes instagram handles from url and @handle input" do
    url_submission = build_submission(instagram_url: "https://www.instagram.com/Acme.Store/?hl=en")
    at_submission = build_submission(instagram_url: "@Acme.Store")

    url_submission.validate
    at_submission.validate

    expect(url_submission.instagram_handle).to eq("acme.store")
    expect(at_submission.instagram_handle).to eq("acme.store")
  end

  it "extracts and normalizes tiktok handles from url and @handle input" do
    url_submission = build_submission(instagram_url: nil, tiktok_url: "https://www.tiktok.com/@AcmeShop/video/123")
    at_submission = build_submission(instagram_url: nil, tiktok_url: "@AcmeShop")

    url_submission.validate
    at_submission.validate

    expect(url_submission.tiktok_handle).to eq("acmeshop")
    expect(at_submission.tiktok_handle).to eq("acmeshop")
  end

  it "normalizes phone numbers to right-most 12 digits when possible" do
    submission = build_submission(instagram_url: nil, phone_raw: "+254 712 345 678 ext 9")

    submission.validate

    expect(submission.phone_normalized).to eq("254712345678")
  end

  it "drops phone normalization for too-short numbers" do
    submission = build_submission(instagram_url: nil, phone_raw: "12345")

    submission.validate

    expect(submission.phone_normalized).to be_nil
  end

  it "sets editable_until around 30 minutes after creation" do
    submission = build_submission
    submission.save!

    expect(submission.editable_until).to be_within(5.seconds).of(submission.created_at + 30.minutes)
  end

  it "is editable until locked or editable_until has passed" do
    submission = build_submission(editable_until: 5.minutes.from_now)
    submission.save!

    expect(submission.editable_now?).to be(true)
    expect(submission.editable_now?(submission.editable_until + 1.second)).to be(false)

    submission.lock!
    expect(submission.editable_now?).to be(false)
  end
end
