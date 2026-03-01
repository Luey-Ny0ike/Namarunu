# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contribute::Submissions", type: :request do
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

  it "allows owner to view their submission" do
    contributor = build_user(:lead_contributor)
    submission = LeadSubmission.create!(
      business_name: "Acme Co",
      instagram_url: "https://instagram.com/acme",
      submitted_by_user: contributor
    )

    sign_in_as(contributor)
    get contribute_submission_path(submission)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Acme Co")
  end

  it "blocks other contributors from viewing a submission they do not own" do
    owner = build_user(:lead_contributor)
    other = build_user(:lead_contributor)
    submission = LeadSubmission.create!(
      business_name: "Acme Co",
      instagram_url: "https://instagram.com/acme",
      submitted_by_user: owner
    )

    sign_in_as(other)
    get contribute_submission_path(submission)

    expect(response).to redirect_to(root_path)
  end

  it "redirects edit when submission is locked" do
    contributor = build_user(:lead_contributor)
    submission = LeadSubmission.create!(
      business_name: "Acme Co",
      instagram_url: "https://instagram.com/acme",
      submitted_by_user: contributor,
      editable_until: 1.minute.ago
    )

    sign_in_as(contributor)
    get edit_contribute_submission_path(submission)

    expect(response).to redirect_to(contribute_submission_path(submission))
    follow_redirect!
    expect(response.body).to include("Locked")
  end

  it "does not update locked submissions" do
    contributor = build_user(:lead_contributor)
    submission = LeadSubmission.create!(
      business_name: "Acme Co",
      instagram_url: "https://instagram.com/acme",
      submitted_by_user: contributor,
      editable_until: 1.minute.ago
    )

    sign_in_as(contributor)
    patch contribute_submission_path(submission), params: { lead_submission: { business_name: "Updated Co" } }

    expect(response).to redirect_to(contribute_submission_path(submission))
    expect(submission.reload.business_name).to eq("Acme Co")
  end
end
