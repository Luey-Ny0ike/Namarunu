# frozen_string_literal: true

class Invoice < ApplicationRecord
  include Validations

  STATUSES        = %w[ draft issued paid void overdue ].freeze
  BILLING_PERIODS = %w[ monthly semi_annually ].freeze
  PLAN_TYPES      = %w[ starter pro business enterprise ].freeze

  belongs_to :store
  belongs_to :store_subscription, class_name: "Store::Subscription", optional: true
  has_many :line_items, class_name: "Invoice::LineItem", dependent: :destroy
  has_many :payments, class_name: "Invoice::Payment", dependent: :destroy

  def plan
    Plan.find(plan_code)
  end
end
