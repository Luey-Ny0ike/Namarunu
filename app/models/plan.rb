# frozen_string_literal: true

class Plan
  attr_reader :code, :name, :tier, :plan_type, :prices, :features, :featured

  def initialize(code:, name:, tier:, plan_type:, prices:, features: [], featured: false)
    @code      = code
    @name      = name
    @tier      = tier
    @plan_type = plan_type
    @prices    = prices
    @features  = features
    @featured  = featured
  end

  def featured? = @featured

  def self.all
    ALL
  end

  def self.find(code)
    ALL.find { |p| p.code == code.to_s }
  end

  def self.standard
    ALL.select { |p| p.tier == :standard }
  end

  def self.startup
    ALL.select { |p| p.tier == :startup }
  end

  def price_for(currency:, billing_period:)
    prices.dig(currency.to_s.upcase, billing_period.to_sym)
  end

  def monthly_equivalent_for(currency:, billing_period:)
    total = price_for(currency: currency, billing_period: billing_period)
    return total if billing_period.to_sym == :monthly

    total / 6
  end

  ALL = [
    new(
      code:      "standard",
      name:      "Standard",
      tier:      :standard,
      plan_type: "starter",
      featured:  false,
      prices: {
        "KES" => { monthly: 650_000,     semi_annually: 3_000_000 },
        "USD" => { monthly: 6_500,       semi_annually: 30_000 },
        "TZS" => { monthly: 14_000_000,  semi_annually: 63_000_000 }
      },
      features: [
        "Online store & Blog",
        "1,000 users",
        "500 SMSs",
        "24/7 support",
        "Unlimited listings",
        "Dedicated phone support",
        "Gift card system",
        "Coupon system",
        "Loyalty point system"
      ]
    ),
    new(
      code:      "growth",
      name:      "Growth",
      tier:      :standard,
      plan_type: "pro",
      featured:  true,
      prices: {
        "KES" => { monthly: 1_300_000,   semi_annually: 6_000_000 },
        "USD" => { monthly: 13_000,      semi_annually: 60_000 },
        "TZS" => { monthly: 27_500_000,  semi_annually: 126_000_000 }
      },
      features: [
        "Online store & Blog",
        "2,500 users",
        "1,000 SMSs",
        "Faster performance",
        "All Standard plan features"
      ]
    ),
    new(
      code:      "scale",
      name:      "Scale",
      tier:      :standard,
      plan_type: "business",
      featured:  false,
      prices: {
        "KES" => { monthly: 1_950_000,   semi_annually: 9_000_000 },
        "USD" => { monthly: 21_000,      semi_annually: 90_000 },
        "TZS" => { monthly: 44_500_000,  semi_annually: 192_000_000 }
      },
      features: [
        "Online store & Blog",
        "6,000 users",
        "1,500 SMSs",
        "Faster performance",
        "All Standard plan features"
      ]
    ),
    new(
      code:      "sungura",
      name:      "Sungura",
      tier:      :startup,
      plan_type: "starter",
      featured:  false,
      prices: {
        "KES" => { monthly: 195_000,     semi_annually: 900_000 },
        "USD" => { monthly: 2_000,       semi_annually: 9_000 },
        "TZS" => { monthly: 4_200_000,   semi_annually: 19_200_000 }
      },
      features: [
        "Online store",
        "100 listings",
        "100 users",
        "150 SMSs",
        "24/7 support",
        "Dedicated email support"
      ]
    ),
    new(
      code:      "chipukizi",
      name:      "Chipukizi",
      tier:      :startup,
      plan_type: "pro",
      featured:  true,
      prices: {
        "KES" => { monthly: 325_000,     semi_annually: 1_500_000 },
        "USD" => { monthly: 3_300,       semi_annually: 15_000 },
        "TZS" => { monthly: 6_800_000,   semi_annually: 31_200_000 }
      },
      features: [
        "Online store",
        "200 listings",
        "200 users",
        "250 SMSs",
        "Faster performance",
        "All Sungura plan features"
      ]
    ),
    new(
      code:      "ndovu",
      name:      "Ndovu",
      tier:      :startup,
      plan_type: "business",
      featured:  false,
      prices: {
        "KES" => { monthly: 455_000,     semi_annually: 2_100_000 },
        "USD" => { monthly: 4_600,       semi_annually: 21_000 },
        "TZS" => { monthly: 9_500_000,   semi_annually: 43_800_000 }
      },
      features: [
        "Online store",
        "300 listings",
        "300 users",
        "350 SMSs",
        "Faster performance",
        "All Sungura plan features"
      ]
    )
  ].freeze

  private_constant :ALL
end
