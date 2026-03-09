# frozen_string_literal: true

class Invoice::LineItem < ApplicationRecord
  KINDS = %w[subscription setup_fee addon discount tax].freeze

  belongs_to :invoice

  before_validation :compute_amount_cents

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

  private

  def compute_amount_cents
    return unless quantity && unit_amount_cents
    self.amount_cents = quantity.to_i * unit_amount_cents.to_i
  end
end
