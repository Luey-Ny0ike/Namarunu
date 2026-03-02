# frozen_string_literal: true

module Invoice::Validations
  extend ActiveSupport::Concern

  included do
    validates :plan_code,
              inclusion: { in: ->(_) { Plan.all.map(&:code) }, message: "is not a recognised plan" },
              allow_blank: true

    validates :plan_type,
              inclusion: { in: Invoice::PLAN_TYPES },
              allow_blank: true

    validates :billing_period,
              inclusion: { in: Invoice::BILLING_PERIODS },
              allow_blank: true

    validates :currency,
              presence: true,
              inclusion: { in: Store::CURRENCIES }

    validates :invoice_number, presence: true, uniqueness: true
    validates :name, presence: true

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
