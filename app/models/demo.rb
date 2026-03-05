# == Schema Information
#
# Table name: demos
#
#  id                  :integer          not null, primary key
#  lead_id             :integer
#  account_id          :integer
#  scheduled_at        :datetime         not null
#  duration_minutes    :integer          default(30), not null
#  status              :string           default("scheduled"), not null
#  outcome             :string
#  notes               :text
#  demo_link           :string
#  created_by_user_id  :integer          not null
#  assigned_to_user_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

# frozen_string_literal: true

class Demo < ApplicationRecord
  STATUSES = {
    scheduled: "scheduled",
    completed: "completed",
    no_show: "no_show",
    rescheduled: "rescheduled",
    cancelled: "cancelled"
  }.freeze

  OUTCOMES = {
    qualified: "qualified",
    follow_up_required: "follow_up_required",
    not_interested: "not_interested",
    not_a_fit: "not_a_fit",
    won: "won",
    lost: "lost"
  }.freeze

  belongs_to :lead, optional: true, inverse_of: :demos
  belongs_to :account, optional: true, inverse_of: :demos
  belongs_to :created_by_user, class_name: "User", inverse_of: :created_demos
  belongs_to :assigned_to_user, class_name: "User", optional: true, inverse_of: :assigned_demos

  has_many :activities, as: :subject, dependent: :destroy

  enum :status, STATUSES, default: :scheduled, validate: true, prefix: true
  enum :outcome, OUTCOMES, validate: { allow_nil: true }, prefix: true

  validates :scheduled_at, :duration_minutes, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }

  scope :attended_or_no_show, -> { where(status: %i[completed no_show]) }
end
