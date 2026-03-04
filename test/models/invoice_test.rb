# frozen_string_literal: true

require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  def valid_attrs
    {
      store:                 stores(:glow_organics),
      name:                  "Glow Organics Kenya",
      email_address:         "glow@example.com",
      phone_number:          "+254700000000",
      store_subscription:    store_subscriptions(:glow_sungura),
      plan_code:             "sungura",
      plan_type:             "starter",
      billing_period:        "monthly",
      currency:              "KES",
      invoice_number:        "99999999",
      billing_period_start:  Date.new(2026, 3, 26),
      billing_period_end:    Date.new(2026, 4, 25),
      status:                "draft",
      subtotal_cents:        195_000,
      discount_cents:        0,
      tax_cents:             0,
      total_cents:           195_000,
      amount_paid_cents:     0,
      amount_due_cents:      195_000
    }
  end

  test "valid invoice saves" do
    assert Invoice.new(valid_attrs).valid?
  end

  test "requires plan_code" do
    invoice = Invoice.new(valid_attrs.merge(plan_code: nil))
    assert_not invoice.valid?
    assert invoice.errors[:plan_code].any?
  end

  test "rejects unrecognised plan_code" do
    invoice = Invoice.new(valid_attrs.merge(plan_code: "diamond"))
    assert_not invoice.valid?
    assert_includes invoice.errors[:plan_code], "is not a recognised plan"
  end

  test "requires plan_type" do
    invoice = Invoice.new(valid_attrs.merge(plan_type: nil))
    assert_not invoice.valid?
    assert invoice.errors[:plan_type].any?
  end

  test "rejects invalid plan_type" do
    invoice = Invoice.new(valid_attrs.merge(plan_type: "unknown"))
    assert_not invoice.valid?
    assert invoice.errors[:plan_type].any?
  end

  test "accepts all valid plan types" do
    Invoice::PLAN_TYPES.each do |type|
      invoice = Invoice.new(valid_attrs.merge(plan_type: type))
      assert invoice.valid?, "expected plan_type '#{type}' to be valid"
    end
  end

  test "requires billing_period" do
    invoice = Invoice.new(valid_attrs.merge(billing_period: nil))
    assert_not invoice.valid?
    assert invoice.errors[:billing_period].any?
  end

  test "rejects invalid billing_period" do
    invoice = Invoice.new(valid_attrs.merge(billing_period: "annually"))
    assert_not invoice.valid?
    assert invoice.errors[:billing_period].any?
  end

  test "requires currency" do
    invoice = Invoice.new(valid_attrs.merge(currency: nil))
    assert_not invoice.valid?
    assert invoice.errors[:currency].any?
  end

  test "rejects unrecognised currency" do
    invoice = Invoice.new(valid_attrs.merge(currency: "GBP"))
    assert_not invoice.valid?
    assert invoice.errors[:currency].any?
  end

  test "requires invoice_number" do
    invoice = Invoice.new(valid_attrs.merge(invoice_number: nil))
    assert_not invoice.valid?
    assert invoice.errors[:invoice_number].any?
  end

  test "invoice_number must be unique" do
    invoice = Invoice.new(valid_attrs.merge(invoice_number: "00000001"))
    assert_not invoice.valid?
    assert_includes invoice.errors[:invoice_number], "has already been taken"
  end

  test "requires billing_period_start" do
    invoice = Invoice.new(valid_attrs.merge(billing_period_start: nil))
    assert_not invoice.valid?
    assert invoice.errors[:billing_period_start].any?
  end

  test "requires billing_period_end" do
    invoice = Invoice.new(valid_attrs.merge(billing_period_end: nil))
    assert_not invoice.valid?
    assert invoice.errors[:billing_period_end].any?
  end

  test "requires status" do
    invoice = Invoice.new(valid_attrs.merge(status: nil))
    assert_not invoice.valid?
    assert invoice.errors[:status].any?
  end

  test "rejects invalid status" do
    invoice = Invoice.new(valid_attrs.merge(status: "pending"))
    assert_not invoice.valid?
    assert invoice.errors[:status].any?
  end

  test "accepts all valid statuses" do
    Invoice::STATUSES.each do |status|
      invoice = Invoice.new(valid_attrs.merge(status: status))
      assert invoice.valid?, "expected status '#{status}' to be valid"
    end
  end

  test "money columns cannot be negative" do
    %i[subtotal_cents discount_cents tax_cents total_cents amount_paid_cents amount_due_cents].each do |col|
      invoice = Invoice.new(valid_attrs.merge(col => -1))
      assert_not invoice.valid?, "expected #{col} = -1 to be invalid"
      assert invoice.errors[col].any?
    end
  end

  test "money columns can be zero" do
    invoice = Invoice.new(valid_attrs.merge(
      subtotal_cents: 0, discount_cents: 0, tax_cents: 0,
      total_cents: 0, amount_paid_cents: 0, amount_due_cents: 0
    ))
    assert invoice.valid?
  end

  test "store_subscription is optional" do
    invoice = Invoice.new(valid_attrs.merge(store_subscription: nil))
    assert invoice.valid?
  end

  test "allows invoice without store when name is provided" do
    invoice = Invoice.new(valid_attrs.merge(store: nil, name: "Walk-in Client"))
    assert invoice.valid?
  end

  test "plan returns the matching Plan object" do
    invoice = Invoice.new(valid_attrs)
    assert_instance_of Plan, invoice.plan
    assert_equal "sungura", invoice.plan.code
  end

  test "has many line items" do
    invoice = invoices(:glow_feb_draft)
    assert_respond_to invoice, :line_items
  end

  test "has many payments" do
    invoice = invoices(:glow_feb_draft)
    assert_respond_to invoice, :payments
  end
end
