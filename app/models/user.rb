# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  email_address :string           not null
#  full_name     :string
#  password_digest :string         not null
#  phone_number  :string
#  role          :string           default("user"), not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_users_on_email_address                           (email_address) UNIQUE
#  index_users_on_full_name_and_email_address_and_role   (full_name,email_address,role)
#
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
