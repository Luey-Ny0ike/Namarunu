class Store::Subscription < ApplicationRecord
  belongs_to :store
  has_many :invoices
end
