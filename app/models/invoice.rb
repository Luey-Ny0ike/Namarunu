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

  def fully_paid?
    total_cents.to_i.positive? && amount_paid_cents.to_i >= total_cents.to_i
  end

  def sync_totals_and_payment_status!
    subtotal = line_items.sum(:amount_cents)
    total = subtotal + tax_cents.to_i
    paid = amount_paid_cents.to_i
    due = [total - paid, 0].max

    next_status = status
    if total.positive? && paid >= total
      next_status = "paid"
    elsif status == "paid" && due.positive?
      next_status = "issued"
    end

    next_issued_at = issued_at
    next_issued_at ||= Date.current if next_status == "paid"

    update_columns(
      subtotal_cents: subtotal,
      total_cents: total,
      amount_due_cents: due,
      status: next_status,
      issued_at: next_issued_at,
      updated_at: Time.current
    )
    reload
  end

  private

  def apply_store_defaults
    return unless store

    self.name = store.name if name.blank?
    self.email_address = store.email_address if email_address.blank?
    self.phone_number = store.phone_number if phone_number.blank?
  end
end
