# frozen_string_literal: true

class Invoice::LineItem < ApplicationRecord
  KINDS = %w[subscription setup_fee addon discount tax].freeze

  belongs_to :invoice

  validates :kind,
    presence: true,
    inclusion: { in: KINDS }

  validates :description, presence: true

  validates :quantity,
    numericality: { only_integer: true, greater_than: 0 }

  validates :unit_amount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :amount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :amount_matches_quantity_and_unit

  private

  def amount_matches_quantity_and_unit
    return unless quantity && unit_amount_cents

    expected = quantity * unit_amount_cents
    return unless amount_cents != expected

    errors.add(:amount_cents, "must equal quantity × unit amount (#{expected})")
  end
end

