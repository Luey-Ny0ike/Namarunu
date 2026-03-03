# frozen_string_literal: true

require "rails_helper"

RSpec.describe Store::Subscription, type: :model do
  def create_store!
    Store.create!(name: "Glow Organics Kenya", currency: "KES", email_address: "glow@example.com")
  end

  def valid_attrs
    {
      store: create_store!,
      plan_code: "sungura",
      billing_period: "monthly",
      currency: "KES",
      current_period_start: Date.new(2026, 2, 26),
      current_period_end: Date.new(2026, 3, 25),
      status: "active",
      quantity: 1,
      unit_amount_cents: 195_000
    }
  end

  it "validates a subscription with valid attributes" do
    expect(described_class.new(valid_attrs)).to be_valid
  end

  it "requires plan_code" do
    sub = described_class.new(valid_attrs.merge(plan_code: nil))

    expect(sub).not_to be_valid
    expect(sub.errors[:plan_code]).to be_present
  end

  it "rejects unrecognised plan_code" do
    sub = described_class.new(valid_attrs.merge(plan_code: "platinum"))

    expect(sub).not_to be_valid
    expect(sub.errors[:plan_code]).to include("is not a recognised plan")
  end

  it "accepts all valid plan codes" do
    Plan.all.map(&:code).each do |code|
      sub = described_class.new(valid_attrs.merge(plan_code: code))
      expect(sub).to be_valid
    end
  end

  it "requires billing_period" do
    sub = described_class.new(valid_attrs.merge(billing_period: nil))

    expect(sub).not_to be_valid
    expect(sub.errors[:billing_period]).to be_present
  end

  it "rejects invalid billing_period" do
    sub = described_class.new(valid_attrs.merge(billing_period: "weekly"))

    expect(sub).not_to be_valid
    expect(sub.errors[:billing_period]).to be_present
  end

  it "accepts semi_annually billing period" do
    sub = described_class.new(valid_attrs.merge(billing_period: "semi_annually"))

    expect(sub).to be_valid
  end

  it "requires currency" do
    sub = described_class.new(valid_attrs.merge(currency: nil))

    expect(sub).not_to be_valid
    expect(sub.errors[:currency]).to be_present
  end

  it "rejects unrecognised currency" do
    sub = described_class.new(valid_attrs.merge(currency: "EUR"))

    expect(sub).not_to be_valid
    expect(sub.errors[:currency]).to be_present
  end

  it "requires status" do
    sub = described_class.new(valid_attrs.merge(status: nil))

    expect(sub).not_to be_valid
    expect(sub.errors[:status]).to be_present
  end

  it "rejects invalid status" do
    sub = described_class.new(valid_attrs.merge(status: "expired"))

    expect(sub).not_to be_valid
    expect(sub.errors[:status]).to be_present
  end

  it "accepts all valid statuses" do
    Store::Subscription::STATUSES.each do |status|
      sub = described_class.new(valid_attrs.merge(status: status))
      expect(sub).to be_valid
    end
  end

  it "requires quantity greater than zero" do
    sub = described_class.new(valid_attrs.merge(quantity: 0))

    expect(sub).not_to be_valid
    expect(sub.errors[:quantity]).to be_present
  end

  it "does not allow negative unit_amount_cents" do
    sub = described_class.new(valid_attrs.merge(unit_amount_cents: -1))

    expect(sub).not_to be_valid
    expect(sub.errors[:unit_amount_cents]).to be_present
  end

  it "allows zero unit_amount_cents" do
    sub = described_class.new(valid_attrs.merge(unit_amount_cents: 0))

    expect(sub).to be_valid
  end

  it "requires current_period_start" do
    sub = described_class.new(valid_attrs.merge(current_period_start: nil))

    expect(sub).not_to be_valid
    expect(sub.errors[:current_period_start]).to be_present
  end

  it "requires current_period_end" do
    sub = described_class.new(valid_attrs.merge(current_period_end: nil))

    expect(sub).not_to be_valid
    expect(sub.errors[:current_period_end]).to be_present
  end

  it "requires current_period_end after current_period_start" do
    sub = described_class.new(valid_attrs.merge(
      current_period_start: Date.new(2026, 3, 1),
      current_period_end: Date.new(2026, 2, 1)
    ))

    expect(sub).not_to be_valid
    expect(sub.errors[:current_period_end]).to include("must be after the period start date")
  end

  it "rejects equal start and end dates" do
    today = Date.new(2026, 2, 26)
    sub = described_class.new(valid_attrs.merge(current_period_start: today, current_period_end: today))

    expect(sub).not_to be_valid
    expect(sub.errors[:current_period_end]).to include("must be after the period start date")
  end

  it "returns matching plan object" do
    sub = described_class.new(valid_attrs)

    expect(sub.plan).to be_a(Plan)
    expect(sub.plan.code).to eq("sungura")
  end

  it "belongs to a store" do
    association = described_class.reflect_on_association(:store)

    expect(association.macro).to eq(:belongs_to)
  end
end
