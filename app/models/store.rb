# frozen_string_literal: true

class Store < ApplicationRecord
  CURRENCIES = %w[KES USD TZS].freeze

  has_many :subscriptions, class_name: "Store::Subscription"
  has_many :invoices

  validates :name, presence: true
  validates :currency, presence: true, inclusion: { in: CURRENCIES }
  validates :email_address,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email" },
            allow_blank: true
end
