# frozen_string_literal: true

module Invoice::Validations
  extend ActiveSupport::Concern

  included do
    validates :plan_code,
              presence: true,
              inclusion: { in: ->(_) { Plan.all.map(&:code) }, message: "is not a recognised plan" }

    validates :plan_type,
              presence: true,
              inclusion: { in: Invoice::PLAN_TYPES }

    validates :billing_period,
              presence: true,
              inclusion: { in: Invoice::BILLING_PERIODS }

    validates :currency,
              presence: true,
              inclusion: { in: Store::CURRENCIES }

    validates :invoice_number, presence: true, uniqueness: true

    validates :billing_period_start, presence: true
    validates :billing_period_end, presence: true

    validates :status,
              presence: true,
              inclusion: { in: Invoice::STATUSES }

    validates :subtotal_cents,
              :discount_cents,
              :tax_cents,
              :total_cents,
              :amount_paid_cents,
              :amount_due_cents,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
