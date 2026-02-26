# frozen_string_literal: true

module Invoice
  class Payment < ApplicationRecord
    STATUSES  = %w[pending succeeded failed refunded].freeze
    PROVIDERS = %w[mpesa equity_bank flutterwave].freeze

    belongs_to :invoice

    validates :provider,
              presence: true,
              inclusion: { in: PROVIDERS }

    validates :status,
              presence: true,
              inclusion: { in: STATUSES }

    validates :amount_cents,
              numericality: { only_integer: true, greater_than: 0 }

    validates :currency,
              presence: true,
              inclusion: { in: Store::CURRENCIES }
  end
end
