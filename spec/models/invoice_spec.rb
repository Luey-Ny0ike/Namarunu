# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice, type: :model do
  def create_store!
    Store.create!(name: "Glow Organics Kenya", currency: "KES", email_address: "glow@example.com")
  end

  def create_subscription!(store)
    Store::Subscription.create!(
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
  end

  def valid_attrs
    store = create_store!
    {
      store: store,
      name: "Glow Organics Kenya",
      email_address: "glow@example.com",
      phone_number: "+254700000000",
      store_subscription: create_subscription!(store),
      plan_code: "sungura",
      plan_type: "starter",
      billing_period: "monthly",
      currency: "KES",
      invoice_number: "99999999",
      billing_period_start: Date.new(2026, 3, 26),
      billing_period_end: Date.new(2026, 4, 25),
      status: "draft",
      subtotal_cents: 195_000,
      discount_cents: 0,
      tax_cents: 0,
      total_cents: 195_000,
      amount_paid_cents: 0,
      amount_due_cents: 195_000
    }
  end

  it "validates a complete invoice" do
    expect(described_class.new(valid_attrs)).to be_valid
  end

  it "allows blank plan_code" do
    invoice = described_class.new(valid_attrs.merge(plan_code: nil))

    expect(invoice).to be_valid
  end

  it "rejects unrecognised plan_code" do
    invoice = described_class.new(valid_attrs.merge(plan_code: "diamond"))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:plan_code]).to include("is not a recognised plan")
  end

  it "allows blank plan_type" do
    invoice = described_class.new(valid_attrs.merge(plan_type: nil))

    expect(invoice).to be_valid
  end

  it "rejects invalid plan_type" do
    invoice = described_class.new(valid_attrs.merge(plan_type: "unknown"))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:plan_type]).to be_present
  end

  it "accepts all valid plan types" do
    Invoice::PLAN_TYPES.each do |type|
      invoice = described_class.new(valid_attrs.merge(plan_type: type))
      expect(invoice).to be_valid
    end
  end

  it "requires billing_period" do
    invoice = described_class.new(valid_attrs.merge(billing_period: nil))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:billing_period]).to be_present
  end

  it "rejects invalid billing_period" do
    invoice = described_class.new(valid_attrs.merge(billing_period: "annually"))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:billing_period]).to be_present
  end

  it "requires currency" do
    invoice = described_class.new(valid_attrs.merge(currency: nil))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:currency]).to be_present
  end

  it "rejects unrecognised currency" do
    invoice = described_class.new(valid_attrs.merge(currency: "GBP"))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:currency]).to be_present
  end

  it "requires invoice_number" do
    invoice = described_class.new(valid_attrs.merge(invoice_number: nil))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:invoice_number]).to be_present
  end

  it "requires unique invoice_number" do
    described_class.create!(valid_attrs.merge(invoice_number: "00000001"))
    duplicate = described_class.new(valid_attrs.merge(invoice_number: "00000001"))

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:invoice_number]).to include("has already been taken")
  end

  it "requires billing_period_start" do
    invoice = described_class.new(valid_attrs.merge(billing_period_start: nil))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:billing_period_start]).to be_present
  end

  it "requires billing_period_end" do
    invoice = described_class.new(valid_attrs.merge(billing_period_end: nil))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:billing_period_end]).to be_present
  end

  it "requires status" do
    invoice = described_class.new(valid_attrs.merge(status: nil))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:status]).to be_present
  end

  it "rejects invalid status" do
    invoice = described_class.new(valid_attrs.merge(status: "pending"))

    expect(invoice).not_to be_valid
    expect(invoice.errors[:status]).to be_present
  end

  it "accepts all valid statuses" do
    Invoice::STATUSES.each do |status|
      invoice = described_class.new(valid_attrs.merge(status: status))
      expect(invoice).to be_valid
    end
  end

  it "rejects negative money columns" do
    %i[subtotal_cents discount_cents tax_cents total_cents amount_paid_cents amount_due_cents].each do |column|
      invoice = described_class.new(valid_attrs.merge(column => -1))
      expect(invoice).not_to be_valid
      expect(invoice.errors[column]).to be_present
    end
  end

  it "allows zero money columns" do
    invoice = described_class.new(valid_attrs.merge(
      subtotal_cents: 0,
      discount_cents: 0,
      tax_cents: 0,
      total_cents: 0,
      amount_paid_cents: 0,
      amount_due_cents: 0
    ))

    expect(invoice).to be_valid
  end

  it "allows nil store_subscription" do
    invoice = described_class.new(valid_attrs.merge(store_subscription: nil))

    expect(invoice).to be_valid
  end

  it "allows invoice without store when name is present" do
    invoice = described_class.new(valid_attrs.merge(store: nil, name: "Walk-in Client"))

    expect(invoice).to be_valid
  end

  it "returns matching plan object" do
    invoice = described_class.new(valid_attrs)

    expect(invoice.plan).to be_a(Plan)
    expect(invoice.plan.code).to eq("sungura")
  end

  it "has many line_items" do
    association = described_class.reflect_on_association(:line_items)

    expect(association.macro).to eq(:has_many)
  end

  it "has many payments" do
    association = described_class.reflect_on_association(:payments)

    expect(association.macro).to eq(:has_many)
  end
end
