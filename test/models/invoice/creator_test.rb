# frozen_string_literal: true

require "test_helper"

class Invoice::CreatorTest < ActiveSupport::TestCase
  setup do
    @subscription = store_subscriptions(:glow_sungura)
  end

  test "creates one invoice record" do
    assert_difference "Invoice.count", 1 do
      Invoice::Creator.new(@subscription).create
    end
  end

  test "creates one line item for the invoice" do
    assert_difference "Invoice::LineItem.count", 1 do
      Invoice::Creator.new(@subscription).create
    end
  end

  test "invoice is created with draft status" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal "draft", invoice.status
  end

  test "invoice snapshots plan_code from subscription" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal @subscription.plan_code, invoice.plan_code
  end

  test "invoice snapshots billing_period from subscription" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal @subscription.billing_period, invoice.billing_period
  end

  test "invoice snapshots currency from subscription" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal @subscription.currency, invoice.currency
  end

  test "invoice billing period dates match subscription period" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal @subscription.current_period_start, invoice.billing_period_start
    assert_equal @subscription.current_period_end, invoice.billing_period_end
  end

  test "amount_paid_cents starts at zero" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal 0, invoice.amount_paid_cents
  end

  test "amount_due_cents equals the subscription unit amount" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal @subscription.unit_amount_cents, invoice.amount_due_cents
  end

  test "total_cents equals subtotal_cents with no discount or tax" do
    invoice = Invoice::Creator.new(@subscription).create
    assert_equal invoice.subtotal_cents, invoice.total_cents
    assert_equal 0, invoice.discount_cents
    assert_equal 0, invoice.tax_cents
  end

  test "line item description includes plan name and billing period" do
    invoice = Invoice::Creator.new(@subscription).create
    line_item = invoice.line_items.first
    assert_includes line_item.description, @subscription.plan.name
    assert_includes line_item.description, @subscription.billing_period.humanize
  end

  test "line item amount equals quantity times unit amount" do
    invoice = Invoice::Creator.new(@subscription).create
    line_item = invoice.line_items.first
    assert_equal @subscription.quantity * @subscription.unit_amount_cents, line_item.amount_cents
  end

  test "generates a unique invoice number" do
    first  = Invoice::Creator.new(store_subscriptions(:glow_sungura)).create
    second = Invoice::Creator.new(store_subscriptions(:glow_sungura_semi)).create
    assert_not_equal first.invoice_number, second.invoice_number
  end

  test "rolls back invoice if line item creation fails" do
    failing_creator = Class.new(Invoice::Creator) do
      def attach_line_items(_invoice)
        raise ActiveRecord::RecordInvalid.new(Invoice::LineItem.new)
      end
    end

    assert_no_difference "Invoice.count" do
      assert_raises(ActiveRecord::RecordInvalid) do
        failing_creator.new(@subscription).create
      end
    end
  end
end
