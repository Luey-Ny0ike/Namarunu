# frozen_string_literal: true

module Store
  class Subscription < ApplicationRecord
    STATUSES        = %w[trialing active paused canceled].freeze
    BILLING_PERIODS = %w[monthly semi_annually].freeze

    belongs_to :store
    has_many :invoices, foreign_key: :store_subscription_id

    validates :plan_code,
              presence: true,
              inclusion: { in: ->(_) { Plan.all.map(&:code) }, message: "is not a recognised plan" }

    validates :billing_period,
              presence: true,
              inclusion: { in: BILLING_PERIODS }

    validates :currency,
              presence: true,
              inclusion: { in: Store::CURRENCIES }

    validates :status,
              presence: true,
              inclusion: { in: STATUSES }

    validates :quantity,
              numericality: { only_integer: true, greater_than: 0 }

    validates :unit_amount_cents,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    validates :current_period_start, presence: true
    validates :current_period_end, presence: true

    validate :period_end_must_be_after_period_start

    def plan
      Plan.find(plan_code)
    end

    private

    def period_end_must_be_after_period_start
      return unless current_period_start && current_period_end

      return unless current_period_end <= current_period_start

      errors.add(:current_period_end, "must be after the period start date")
    end
  end
end
