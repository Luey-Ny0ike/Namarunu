# frozen_string_literal: true

require "test_helper"

class Invoice::LineItemTest < ActiveSupport::TestCase
  def valid_attrs
    {
      invoice:           invoices(:glow_feb_draft),
      kind:              "subscription",
      description:       "Sungura plan (Monthly)",
      quantity:          1,
      unit_amount_cents: 195_000,
      amount_cents:      195_000
    }
  end

  test "valid line item saves" do
    assert Invoice::LineItem.new(valid_attrs).valid?
  end

  test "requires kind" do
    item = Invoice::LineItem.new(valid_attrs.merge(kind: nil))
    assert_not item.valid?
    assert item.errors[:kind].any?
  end

  test "rejects invalid kind" do
    item = Invoice::LineItem.new(valid_attrs.merge(kind: "fee"))
    assert_not item.valid?
    assert item.errors[:kind].any?
  end

  test "accepts all valid kinds" do
    Invoice::LineItem::KINDS.each do |kind|
      item = Invoice::LineItem.new(valid_attrs.merge(kind: kind))
      assert item.valid?, "expected kind '#{kind}' to be valid"
    end
  end

  test "requires description" do
    item = Invoice::LineItem.new(valid_attrs.merge(description: nil))
    assert_not item.valid?
    assert item.errors[:description].any?
  end

  test "quantity must be greater than zero" do
    item = Invoice::LineItem.new(valid_attrs.merge(quantity: 0))
    assert_not item.valid?
    assert item.errors[:quantity].any?
  end

  test "unit_amount_cents cannot be negative" do
    item = Invoice::LineItem.new(valid_attrs.merge(unit_amount_cents: -1))
    assert_not item.valid?
    assert item.errors[:unit_amount_cents].any?
  end

  test "unit_amount_cents can be zero" do
    item = Invoice::LineItem.new(valid_attrs.merge(unit_amount_cents: 0, amount_cents: 0))
    assert item.valid?
  end

  test "amount_cents must equal quantity times unit_amount_cents" do
    item = Invoice::LineItem.new(valid_attrs.merge(quantity: 2, unit_amount_cents: 195_000, amount_cents: 195_000))
    assert_not item.valid?
    assert_includes item.errors[:amount_cents], "must equal quantity × unit amount (390000)"
  end

  test "amount_cents is valid when it matches quantity times unit_amount_cents" do
    item = Invoice::LineItem.new(valid_attrs.merge(quantity: 2, unit_amount_cents: 195_000, amount_cents: 390_000))
    assert item.valid?
  end

  test "belongs to an invoice" do
    item = invoice_line_items(:glow_feb_subscription_line)
    assert_instance_of Invoice, item.invoice
  end
end
