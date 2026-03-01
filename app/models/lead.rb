# frozen_string_literal: true

class Lead < ApplicationRecord
  STATUSES = {
    new: "new",
    contacted: "contacted",
    qualified: "qualified",
    proposal_sent: "proposal_sent",
    won: "won",
    lost: "lost"
  }.freeze

  TEMPERATURES = {
    cold: "cold",
    warm: "warm",
    hot: "hot"
  }.freeze

  belongs_to :owner_user, class_name: "User", optional: true, inverse_of: :owned_leads

  has_many :lead_contacts, dependent: :destroy, inverse_of: :lead
  has_many :lead_assignments, dependent: :destroy
  has_many :activities, as: :subject, dependent: :destroy

  accepts_nested_attributes_for :lead_contacts, allow_destroy: true, reject_if: :all_blank

  enum :status, STATUSES, default: :new, validate: true, prefix: true
  enum :temperature, TEMPERATURES, default: :warm, validate: true, prefix: true

  validates :business_name, presence: true
  validate :must_have_at_least_one_contact

  scope :follow_ups_due, -> { where.not(next_action_at: nil).where(next_action_at: ..Time.zone.now.end_of_day) }

  def owned_by?(user)
    user.present? && owner_user_id == user.id
  end

  def active_assignment(time = Time.current)
    lead_assignments.includes(:user).active_at(time).order(expires_at: :asc).first
  end

  def checked_out_by?(user, time = Time.current)
    user.present? && active_assignment(time)&.user_id == user.id
  end

  def editable_by?(user)
    owned_by?(user) || checked_out_by?(user)
  end

  private

  def must_have_at_least_one_contact
    remaining_contacts = lead_contacts.reject(&:marked_for_destruction?)
    errors.add(:lead_contacts, "must include at least one contact") if remaining_contacts.empty?
  end
end
