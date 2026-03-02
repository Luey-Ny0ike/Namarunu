# frozen_string_literal: true

class Invoice < ApplicationRecord
  STATUSES        = %w[ draft issued paid void overdue ].freeze
  BILLING_PERIODS = %w[ monthly semi_annually ].freeze
  PLAN_TYPES      = %w[ starter pro business enterprise ].freeze

  include Validations

  before_validation :apply_store_defaults

  belongs_to :store, optional: true
  belongs_to :store_subscription, class_name: "Store::Subscription", optional: true
  has_many :line_items, class_name: "Invoice::LineItem", dependent: :destroy
  has_many :payments, class_name: "Invoice::Payment", dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank

  def plan
    plan_code.present? ? Plan.find(plan_code) : nil
  end

  def recipient_name
    name.presence || store&.name
  end

  def recipient_email
    email_address.presence || store&.email_address
  end

  def recipient_phone
    phone_number.presence || store&.phone_number
  end

  private

  def apply_store_defaults
    return unless store

    self.name = store.name if name.blank?
    self.email_address = store.email_address if email_address.blank?
    self.phone_number = store.phone_number if phone_number.blank?
  end
end
