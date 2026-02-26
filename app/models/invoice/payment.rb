class Invoice::Payment < ApplicationRecord
  belongs_to :invoice
end
