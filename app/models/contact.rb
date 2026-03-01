# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :account, inverse_of: :contacts

  validates :name, presence: true
end
