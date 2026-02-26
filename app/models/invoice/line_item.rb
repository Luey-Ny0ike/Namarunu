class Invoice::LineItem < ApplicationRecord
  belongs_to :invoice
end
