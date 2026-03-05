# == Schema Information
#
# Table name: lead_assignments
#
#  id             :integer          not null, primary key
#  lead_id        :integer          not null
#  user_id        :integer          not null
#  checked_out_at :datetime         not null
#  expires_at     :datetime         not null
#  released_at    :datetime
#  release_reason :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

# frozen_string_literal: true

class LeadAssignment < ApplicationRecord
  belongs_to :lead
  belongs_to :user

  scope :unreleased, -> { where(released_at: nil) }
  scope :active_at, ->(time = Time.current) { unreleased.where("expires_at > ?", time) }

  validates :checked_out_at, :expires_at, presence: true
  validate :expires_after_checkout

  def active?(time = Time.current)
    released_at.nil? && expires_at > time
  end

  def release!(reason:, at: Time.current)
    update!(released_at: at, release_reason: reason)
  end

  private

  def expires_after_checkout
    return if checked_out_at.blank? || expires_at.blank?
    return if expires_at > checked_out_at

    errors.add(:expires_at, "must be after checked_out_at")
  end
end
