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
  ROLES = {
    super_admin: "super_admin",
    sales_manager: "sales_manager",
    sales_rep: "sales_rep",
    support: "support",
    finance: "finance"
  }.freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :owned_inquiries, class_name: "Inquiry", foreign_key: :owner_id, inverse_of: :owner, dependent: :nullify
  has_many :checked_out_inquiries, class_name: "Inquiry", foreign_key: :checked_out_by_id, inverse_of: :checked_out_by, dependent: :nullify
  has_many :owned_leads, class_name: "Lead", foreign_key: :owner_user_id, inverse_of: :owner_user, dependent: :nullify
  has_many :lead_assignments, dependent: :restrict_with_exception
  has_many :activities, class_name: "Activity", foreign_key: :actor_user_id, inverse_of: :actor_user, dependent: :restrict_with_exception

  enum :role, ROLES, default: :sales_rep

  validates :role, inclusion: { in: roles.keys }
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
