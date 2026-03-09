# frozen_string_literal: true

require "test_helper"

class Store::SubscriptionTest < ActiveSupport::TestCase
  def valid_attrs
    {
      store:                stores(:glow_organics),
      plan_code:            "sungura",
      billing_period:       "monthly",
      currency:             "KES",
      current_period_start: Date.new(2026, 2, 26),
      current_period_end:   Date.new(2026, 3, 25),
      status:               "active",
      quantity:             1,
      unit_amount_cents:    195_000
    }
  end

  test "valid subscription saves" do
    assert Store::Subscription.new(valid_attrs).valid?
  end

  test "requires plan_code" do
    sub = Store::Subscription.new(valid_attrs.merge(plan_code: nil))
    assert_not sub.valid?
    assert sub.errors[:plan_code].any?
  end

  test "rejects unrecognised plan_code" do
    sub = Store::Subscription.new(valid_attrs.merge(plan_code: "platinum"))
    assert_not sub.valid?
    assert_includes sub.errors[:plan_code], "is not a recognised plan"
  end

  test "accepts all valid plan codes" do
    Plan.all.map(&:code).each do |code|
      sub = Store::Subscription.new(valid_attrs.merge(plan_code: code))
      assert sub.valid?, "expected plan_code '#{code}' to be valid"
    end
  end

  test "requires billing_period" do
    sub = Store::Subscription.new(valid_attrs.merge(billing_period: nil))
    assert_not sub.valid?
    assert sub.errors[:billing_period].any?
  end

  test "rejects invalid billing_period" do
    sub = Store::Subscription.new(valid_attrs.merge(billing_period: "weekly"))
    assert_not sub.valid?
    assert sub.errors[:billing_period].any?
  end

  test "accepts semi_annually billing period" do
    sub = Store::Subscription.new(valid_attrs.merge(billing_period: "semi_annually"))
    assert sub.valid?
  end

  test "requires currency" do
    sub = Store::Subscription.new(valid_attrs.merge(currency: nil))
    assert_not sub.valid?
    assert sub.errors[:currency].any?
  end

  test "rejects unrecognised currency" do
    sub = Store::Subscription.new(valid_attrs.merge(currency: "EUR"))
    assert_not sub.valid?
    assert sub.errors[:currency].any?
  end

  test "requires status" do
    sub = Store::Subscription.new(valid_attrs.merge(status: nil))
    assert_not sub.valid?
    assert sub.errors[:status].any?
  end

  test "rejects invalid status" do
    sub = Store::Subscription.new(valid_attrs.merge(status: "expired"))
    assert_not sub.valid?
    assert sub.errors[:status].any?
  end

  test "accepts all valid statuses" do
    Store::Subscription::STATUSES.each do |status|
      sub = Store::Subscription.new(valid_attrs.merge(status: status))
      assert sub.valid?, "expected status '#{status}' to be valid"
    end
  end

  test "quantity must be greater than zero" do
    sub = Store::Subscription.new(valid_attrs.merge(quantity: 0))
    assert_not sub.valid?
    assert sub.errors[:quantity].any?
  end

  test "unit_amount_cents cannot be negative" do
    sub = Store::Subscription.new(valid_attrs.merge(unit_amount_cents: -1))
    assert_not sub.valid?
    assert sub.errors[:unit_amount_cents].any?
  end

  test "unit_amount_cents can be zero" do
    sub = Store::Subscription.new(valid_attrs.merge(unit_amount_cents: 0))
    assert sub.valid?
  end

  test "requires current_period_start" do
    sub = Store::Subscription.new(valid_attrs.merge(current_period_start: nil))
    assert_not sub.valid?
    assert sub.errors[:current_period_start].any?
  end

  test "requires current_period_end" do
    sub = Store::Subscription.new(valid_attrs.merge(current_period_end: nil))
    assert_not sub.valid?
    assert sub.errors[:current_period_end].any?
  end

  test "period_end must be after period_start" do
    sub = Store::Subscription.new(valid_attrs.merge(
      current_period_start: Date.new(2026, 3, 1),
      current_period_end:   Date.new(2026, 2, 1)
    ))
    assert_not sub.valid?
    assert_includes sub.errors[:current_period_end], "must be after the period start date"
  end

  test "period_end equal to period_start is invalid" do
    today = Date.new(2026, 2, 26)
    sub = Store::Subscription.new(valid_attrs.merge(
      current_period_start: today,
      current_period_end:   today
    ))
    assert_not sub.valid?
    assert_includes sub.errors[:current_period_end], "must be after the period start date"
  end

  test "plan returns the matching Plan object" do
    sub = Store::Subscription.new(valid_attrs)
    assert_instance_of Plan, sub.plan
    assert_equal "sungura", sub.plan.code
  end

  test "belongs to a store" do
    sub = store_subscriptions(:glow_sungura)
    assert_instance_of Store, sub.store
  end
end
