# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice::Creator, type: :model do
  def create_subscription!(billing_period: "monthly")
    store = Store.create!(name: "Glow Organics Kenya", currency: "KES", email_address: "glow@example.com")

    Store::Subscription.create!(
      store: store,
      plan_code: "sungura",
      billing_period: billing_period,
      currency: "KES",
      current_period_start: Date.new(2026, 2, 26),
      current_period_end: Date.new(2026, 3, 25),
      status: "active",
      quantity: 1,
      unit_amount_cents: 195_000
    )
  end

  it "creates one invoice record" do
    subscription = create_subscription!

    expect { described_class.new(subscription).create }.to change(Invoice, :count).by(1)
  end

  it "creates one line item for the invoice" do
    subscription = create_subscription!

    expect { described_class.new(subscription).create }.to change(Invoice::LineItem, :count).by(1)
  end

  it "creates invoice in draft status" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.status).to eq("draft")
  end

  it "snapshots plan_code from subscription" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.plan_code).to eq(subscription.plan_code)
  end

  it "snapshots billing_period from subscription" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.billing_period).to eq(subscription.billing_period)
  end

  it "snapshots currency from subscription" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.currency).to eq(subscription.currency)
  end

  it "copies billing period dates from subscription" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.billing_period_start).to eq(subscription.current_period_start)
    expect(invoice.billing_period_end).to eq(subscription.current_period_end)
  end

  it "starts with zero amount_paid_cents" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.amount_paid_cents).to eq(0)
  end

  it "sets amount_due_cents to subscription total" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.amount_due_cents).to eq(subscription.unit_amount_cents)
  end

  it "sets total equal to subtotal with zero discount and tax" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create

    expect(invoice.total_cents).to eq(invoice.subtotal_cents)
    expect(invoice.discount_cents).to eq(0)
    expect(invoice.tax_cents).to eq(0)
  end

  it "builds line item description from plan and billing period" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create
    line_item = invoice.line_items.first

    expect(line_item.description).to include(subscription.plan.name)
    expect(line_item.description).to include(subscription.billing_period.humanize)
  end

  it "sets line item amount to quantity x unit amount" do
    subscription = create_subscription!
    invoice = described_class.new(subscription).create
    line_item = invoice.line_items.first

    expect(line_item.amount_cents).to eq(subscription.quantity * subscription.unit_amount_cents)
  end

  it "generates unique invoice numbers" do
    first = described_class.new(create_subscription!(billing_period: "monthly")).create
    second = described_class.new(create_subscription!(billing_period: "semi_annually")).create

    expect(first.invoice_number).not_to eq(second.invoice_number)
  end

  it "rolls back invoice creation if line item creation fails" do
    subscription = create_subscription!
    failing_creator = Class.new(described_class) do
      private

      def attach_line_items(_invoice)
        raise ActiveRecord::RecordInvalid, Invoice::LineItem.new
      end
    end

    expect do
      expect { failing_creator.new(subscription).create }.to raise_error(ActiveRecord::RecordInvalid)
    end.not_to change(Invoice, :count)
  end
end
