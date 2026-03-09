# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice::Payment, type: :model do
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
      provider: "mpesa",
      provider_ref: "MPESATEST001",
      status: "pending",
      amount_cents: 195_000,
      currency: "KES"
    }
  end

  it "validates a payment with valid attributes" do
    expect(described_class.new(valid_attrs)).to be_valid
  end

  it "requires provider" do
    payment = described_class.new(valid_attrs.merge(provider: nil))

    expect(payment).not_to be_valid
    expect(payment.errors[:provider]).to be_present
  end

  it "rejects unrecognised provider" do
    payment = described_class.new(valid_attrs.merge(provider: "paypal"))

    expect(payment).not_to be_valid
    expect(payment.errors[:provider]).to be_present
  end

  it "accepts all valid providers" do
    described_class::PROVIDERS.each do |provider|
      payment = described_class.new(valid_attrs.merge(provider: provider))
      expect(payment).to be_valid
    end
  end

  it "requires status" do
    payment = described_class.new(valid_attrs.merge(status: nil))

    expect(payment).not_to be_valid
    expect(payment.errors[:status]).to be_present
  end

  it "rejects invalid status" do
    payment = described_class.new(valid_attrs.merge(status: "cancelled"))

    expect(payment).not_to be_valid
    expect(payment.errors[:status]).to be_present
  end

  it "accepts all valid statuses" do
    described_class::STATUSES.each do |status|
      payment = described_class.new(valid_attrs.merge(status: status))
      expect(payment).to be_valid
    end
  end

  it "requires amount_cents greater than zero" do
    payment = described_class.new(valid_attrs.merge(amount_cents: 0))

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to be_present
  end

  it "does not allow negative amount_cents" do
    payment = described_class.new(valid_attrs.merge(amount_cents: -100))

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to be_present
  end

  it "requires currency" do
    payment = described_class.new(valid_attrs.merge(currency: nil))

    expect(payment).not_to be_valid
    expect(payment.errors[:currency]).to be_present
  end

  it "rejects unrecognised currency" do
    payment = described_class.new(valid_attrs.merge(currency: "EUR"))

    expect(payment).not_to be_valid
    expect(payment.errors[:currency]).to be_present
  end

  it "allows provider_ref to be blank" do
    payment = described_class.new(valid_attrs.merge(provider_ref: nil))

    expect(payment).to be_valid
  end

  it "belongs to an invoice" do
    association = described_class.reflect_on_association(:invoice)

    expect(association.macro).to eq(:belongs_to)
  end
end
