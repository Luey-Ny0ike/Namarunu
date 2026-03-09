# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice::LineItem, type: :model do
  def create_invoice!
    store = Store.create!(name: "Glow Organics Kenya", currency: "KES")
    subscription = Store::Subscription.create!(
      store: store,
      plan_code: "sungura",
      billing_period: "monthly",
      currency: "KES",
      current_period_start: Date.new(2026, 2, 26),
      current_period_end: Date.new(2026, 3, 25),
      status: "active",
      quantity: 1,
      unit_amount_cents: 195_000
    )

    Invoice.create!(
      store: store,
      store_subscription: subscription,
      name: "Glow Organics Kenya",
      plan_code: "sungura",
      plan_type: "starter",
      billing_period: "monthly",
      currency: "KES",
      invoice_number: format("%08d", SecureRandom.random_number(90_000_000) + 10_000_000),
      billing_period_start: Date.new(2026, 3, 26),
      billing_period_end: Date.new(2026, 4, 25),
      status: "draft",
      subtotal_cents: 195_000,
      discount_cents: 0,
      tax_cents: 0,
      total_cents: 195_000,
      amount_paid_cents: 0,
      amount_due_cents: 195_000
    )
  end

  def valid_attrs
    {
      invoice: create_invoice!,
      kind: "subscription",
      description: "Sungura plan (Monthly)",
      quantity: 1,
      unit_amount_cents: 195_000,
      amount_cents: 195_000
    }
  end

  it "validates with valid attributes" do
    expect(described_class.new(valid_attrs)).to be_valid
  end

  it "requires kind" do
    item = described_class.new(valid_attrs.merge(kind: nil))

    expect(item).not_to be_valid
    expect(item.errors[:kind]).to be_present
  end

  it "rejects invalid kind" do
    item = described_class.new(valid_attrs.merge(kind: "fee"))

    expect(item).not_to be_valid
    expect(item.errors[:kind]).to be_present
  end

  it "accepts all valid kinds" do
    described_class::KINDS.each do |kind|
      item = described_class.new(valid_attrs.merge(kind: kind))
      expect(item).to be_valid
    end
  end

  it "requires description" do
    item = described_class.new(valid_attrs.merge(description: nil))

    expect(item).not_to be_valid
    expect(item.errors[:description]).to be_present
  end

  it "requires quantity greater than zero" do
    item = described_class.new(valid_attrs.merge(quantity: 0))

    expect(item).not_to be_valid
    expect(item.errors[:quantity]).to be_present
  end

  it "does not allow negative unit_amount_cents" do
    item = described_class.new(valid_attrs.merge(unit_amount_cents: -1))

    expect(item).not_to be_valid
    expect(item.errors[:unit_amount_cents]).to be_present
  end

  it "allows zero unit_amount_cents" do
    item = described_class.new(valid_attrs.merge(unit_amount_cents: 0, amount_cents: 0))

    expect(item).to be_valid
  end

  it "recomputes amount_cents from quantity and unit_amount_cents" do
    item = described_class.new(valid_attrs.merge(quantity: 2, unit_amount_cents: 195_000, amount_cents: 1))
    item.valid?

    expect(item.amount_cents).to eq(390_000)
    expect(item.errors[:amount_cents]).to be_empty
  end

  it "belongs to an invoice" do
    association = described_class.reflect_on_association(:invoice)

    expect(association.macro).to eq(:belongs_to)
  end
end
