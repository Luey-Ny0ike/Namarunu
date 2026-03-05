# == Schema Information
#
# Table name: accounts
#
#  id                     :integer          not null, primary key
#  name                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  converted_from_lead_id :integer
#

# frozen_string_literal: true

class Account < ApplicationRecord
  belongs_to :converted_from_lead, class_name: "Lead", optional: true, inverse_of: :converted_account

  has_many :contacts, dependent: :destroy, inverse_of: :account
  has_many :demos, dependent: :nullify

  validates :name, presence: true
end
