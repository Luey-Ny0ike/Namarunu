# frozen_string_literal: true

require "rails_helper"

RSpec.describe Demo, type: :model do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: role
    )
  end

  it "requires schedule and positive duration" do
    creator = build_user(:sales_rep)
    demo = described_class.new(created_by_user: creator, duration_minutes: 0)

    expect(demo).not_to be_valid
    expect(demo.errors[:scheduled_at]).to be_present
    expect(demo.errors[:duration_minutes]).to be_present
  end

  it "supports attended_or_no_show scope" do
    creator = build_user(:sales_rep)
    completed = described_class.create!(scheduled_at: 1.day.ago, duration_minutes: 30, status: :completed, created_by_user: creator)
    no_show = described_class.create!(scheduled_at: 2.days.ago, duration_minutes: 30, status: :no_show, created_by_user: creator)
    described_class.create!(scheduled_at: 1.day.from_now, duration_minutes: 30, status: :scheduled, created_by_user: creator)

    expect(described_class.attended_or_no_show).to contain_exactly(completed, no_show)
  end

  it "defaults meeting_type to virtual" do
    creator = build_user(:sales_rep)
    demo = described_class.create!(scheduled_at: 1.day.from_now, duration_minutes: 30, created_by_user: creator)

    expect(demo.meeting_type).to eq("virtual")
    expect(demo.meeting_type_virtual?).to be(true)
  end
end
