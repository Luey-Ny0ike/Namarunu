class Invoice < ApplicationRecord
  belongs_to :store
  belongs_to :store_subscriptions, optional: true

  has_many :invoice_line_items
  has_many :invoice_payments
end
