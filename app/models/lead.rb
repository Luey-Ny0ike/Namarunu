# frozen_string_literal: true

class Lead < ApplicationRecord
  STATUSES = {
    new: "new",
    in_progress: "in_progress",
    contacted: "contacted",
    qualified: "qualified",
    demo_booked: "demo_booked",
    demo_completed: "demo_completed",
    won: "won",
    lost: "lost",
    unresponsive: "unresponsive"
  }.freeze

  TEMPERATURES = {
    cold: "cold",
    warm: "warm",
    hot: "hot"
  }.freeze

  CALL_OUTCOMES = {
    no_answer: "no_answer",
    wrong_number: "wrong_number",
    interested: "interested",
    not_interested: "not_interested",
    follow_up: "follow_up",
    booked_demo: "booked_demo"
  }.freeze

  CALL_OUTCOME_STATUS_TRANSITIONS = {
    "no_answer" => "in_progress",
    "wrong_number" => "lost",
    "interested" => "qualified",
    "not_interested" => "lost",
    "follow_up" => "contacted",
    "booked_demo" => "demo_booked"
  }.freeze

  belongs_to :owner_user, class_name: "User", optional: true, inverse_of: :owned_leads

  has_many :lead_contacts, dependent: :destroy, inverse_of: :lead
  has_many :lead_assignments, dependent: :destroy
  has_many :activities, as: :subject, dependent: :destroy
  has_many :demos, dependent: :nullify
  has_one :converted_account, class_name: "Account", foreign_key: :converted_from_lead_id, inverse_of: :converted_from_lead, dependent: :nullify

  accepts_nested_attributes_for :lead_contacts, allow_destroy: true, reject_if: :all_blank

  enum :status, STATUSES, default: :new, validate: true, prefix: true
  enum :temperature, TEMPERATURES, default: :warm, validate: true, prefix: true

  validates :business_name, presence: true
  validate :must_have_at_least_one_contact

  scope :follow_ups_due, -> { where.not(next_action_at: nil).where(next_action_at: ..Time.zone.now.end_of_day) }

  def self.call_outcome_status_transition(outcome)
    CALL_OUTCOME_STATUS_TRANSITIONS[outcome.to_s]
  end

  def self.follow_up_outcome?(outcome)
    outcome.to_s == CALL_OUTCOMES[:follow_up]
  end

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

  def conversion_eligible?
    status_qualified? || status_demo_booked? || status_demo_completed?
  end

  private

  def must_have_at_least_one_contact
    remaining_contacts = lead_contacts.reject(&:marked_for_destruction?)
    errors.add(:lead_contacts, "must include at least one contact") if remaining_contacts.empty?
  end
end
