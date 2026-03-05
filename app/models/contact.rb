# == Schema Information
#
# Table name: contacts
#
#  id         :integer          not null, primary key
#  account_id :integer          not null
#  name       :string           not null
#  phone      :string
#  email      :string
#  role       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# frozen_string_literal: true

class Contact < ApplicationRecord
  belongs_to :account, inverse_of: :contacts

  validates :name, presence: true
end
