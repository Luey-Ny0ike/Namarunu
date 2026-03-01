# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadSubmissionPolicy do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  let(:owner) { build_user(:lead_contributor) }
  let(:other_contributor) { build_user(:lead_contributor) }
  let(:super_admin) { build_user(:super_admin) }
  let(:submission) do
    LeadSubmission.create!(
      business_name: "Acme Co",
      instagram_url: "https://instagram.com/acme",
      submitted_by_user: owner
    )
  end

  it "allows owners to view and update their submissions" do
    policy = described_class.new(owner, submission)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "prevents other contributors from viewing or updating" do
    policy = described_class.new(other_contributor, submission)

    expect(policy.show?).to be(false)
    expect(policy.update?).to be(false)
  end

  it "allows super_admin to view and update all submissions" do
    policy = described_class.new(super_admin, submission)

    expect(policy.show?).to be(true)
    expect(policy.update?).to be(true)
  end

  it "scopes regular contributors to own submissions" do
    other_submission = LeadSubmission.create!(
      business_name: "Other Co",
      tiktok_url: "https://tiktok.com/@other",
      submitted_by_user: other_contributor
    )

    result = described_class::Scope.new(owner, LeadSubmission).resolve

    expect(result).to include(submission)
    expect(result).not_to include(other_submission)
  end

  it "scopes super_admin to all submissions" do
    LeadSubmission.create!(
      business_name: "Other Co",
      tiktok_url: "https://tiktok.com/@other",
      submitted_by_user: other_contributor
    )

    result = described_class::Scope.new(super_admin, LeadSubmission).resolve

    expect(result.count).to eq(LeadSubmission.count)
  end
end
