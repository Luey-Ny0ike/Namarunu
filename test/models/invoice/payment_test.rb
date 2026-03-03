# frozen_string_literal: true

require "test_helper"

class Invoice::PaymentTest < ActiveSupport::TestCase
  def valid_attrs
    {
      invoice:      invoices(:glow_feb_draft),
      provider:     "mpesa",
      provider_ref: "MPESATEST001",
      status:       "pending",
      amount_cents: 195_000,
      currency:     "KES"
    }
  end

  test "valid payment saves" do
    assert Invoice::Payment.new(valid_attrs).valid?
  end

  test "requires provider" do
    payment = Invoice::Payment.new(valid_attrs.merge(provider: nil))
    assert_not payment.valid?
    assert payment.errors[:provider].any?
  end

  test "rejects unrecognised provider" do
    payment = Invoice::Payment.new(valid_attrs.merge(provider: "paypal"))
    assert_not payment.valid?
    assert payment.errors[:provider].any?
  end

  test "accepts all valid providers" do
    Invoice::Payment::PROVIDERS.each do |provider|
      payment = Invoice::Payment.new(valid_attrs.merge(provider: provider))
      assert payment.valid?, "expected provider '#{provider}' to be valid"
    end
  end

  test "requires status" do
    payment = Invoice::Payment.new(valid_attrs.merge(status: nil))
    assert_not payment.valid?
    assert payment.errors[:status].any?
  end

  test "rejects invalid status" do
    payment = Invoice::Payment.new(valid_attrs.merge(status: "cancelled"))
    assert_not payment.valid?
    assert payment.errors[:status].any?
  end

  test "accepts all valid statuses" do
    Invoice::Payment::STATUSES.each do |status|
      payment = Invoice::Payment.new(valid_attrs.merge(status: status))
      assert payment.valid?, "expected status '#{status}' to be valid"
    end
  end

  test "amount_cents must be greater than zero" do
    payment = Invoice::Payment.new(valid_attrs.merge(amount_cents: 0))
    assert_not payment.valid?
    assert payment.errors[:amount_cents].any?
  end

  test "amount_cents cannot be negative" do
    payment = Invoice::Payment.new(valid_attrs.merge(amount_cents: -100))
    assert_not payment.valid?
    assert payment.errors[:amount_cents].any?
  end

  test "requires currency" do
    payment = Invoice::Payment.new(valid_attrs.merge(currency: nil))
    assert_not payment.valid?
    assert payment.errors[:currency].any?
  end

  test "rejects unrecognised currency" do
    payment = Invoice::Payment.new(valid_attrs.merge(currency: "EUR"))
    assert_not payment.valid?
    assert payment.errors[:currency].any?
  end

  test "provider_ref is optional" do
    payment = Invoice::Payment.new(valid_attrs.merge(provider_ref: nil))
    assert payment.valid?
  end

  test "belongs to an invoice" do
    payment = invoice_payments(:glow_mpesa_pending)
    assert_instance_of Invoice, payment.invoice
  end
end
