# frozen_string_literal: true

store = Store.find_or_create_by!(email_address: "hello@gloworganics.co.ke") do |s|
  s.name         = "Glow Organics Kenya"
  s.currency     = "KES"
  s.phone_number = "+254 712 345 678"
end

subscription = Store::Subscription.find_or_create_by!(
  store:                store,
  plan_code:            "sungura",
  billing_period:       "monthly",
  current_period_start: Date.new(2026, 2, 1),
  current_period_end:   Date.new(2026, 2, 28)
) do |s|
  s.currency          = "KES"
  s.status            = "active"
  s.quantity          = 1
  s.unit_amount_cents = 195_000
end

unless Invoice.exists?(store_subscription: subscription,
                        billing_period_start: subscription.current_period_start,
                        billing_period_end:   subscription.current_period_end)
  Invoice::Creator.new(subscription).create
end
