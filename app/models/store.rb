class Store < ApplicationRecord
  has_many :store_subscriptions
  has_many :invoices
end
