# frozen_string_literal: true

class Lead < ApplicationRecord
  STATUSES = {
    new: "new",
    in_progress: "in_progress",
    contacted: "contacted",
    qualified: "qualified",
    demo_booked: "demo_booked",
    demo_completed: "demo_completed",
    awaiting_commitment: "awaiting_commitment",
    invoice_sent: "invoice_sent",
    won: "won",
    lost: "lost",
    unresponsive: "unresponsive"
  }.freeze

  LOST_REASONS = {
    too_expensive: "too_expensive",
    not_ready: "not_ready",
    competitor: "competitor",
    no_response: "no_response",
    not_a_fit: "not_a_fit",
    invalid_contact: "invalid_contact",
    other: "other"
  }.freeze

  TEMPERATURES = {
    cold: "cold",
    warm: "warm",
    hot: "hot"
  }.freeze

  INDUSTRIES = {
    retail: "retail",
    household_goods: "household_goods",
    jewellery: "jewellery",
    beauty: "beauty",
    liqour_store: "liqour_store",
    fashion: "fashion",
    other: "other"
  }.freeze

  SOURCES = {
    instagram: "instagram",
    tiktok: "tiktok",
    referral: "referral",
    walk_in: "walk_in",
    website: "website",
    contributor: "contributor",
    other: "other"
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
  has_many :lead_submissions, dependent: :nullify
  has_many :lead_assignments, dependent: :destroy
  has_many :activities, as: :subject, dependent: :destroy
  has_many :demos, dependent: :nullify
  has_one :converted_account, class_name: "Account", foreign_key: :converted_from_lead_id, inverse_of: :converted_from_lead, dependent: :nullify

  accepts_nested_attributes_for :lead_contacts, allow_destroy: true, reject_if: :all_blank

  enum :status, STATUSES, default: :new, validate: true, prefix: true
  enum :temperature, TEMPERATURES, default: :warm, validate: true, prefix: true
  enum :lost_reason, LOST_REASONS, validate: { allow_nil: true }, prefix: true

  validates :business_name, presence: true
  validates :lost_reason, presence: true, if: :status_lost?
  validates :invoice_sent_at, presence: true, if: :status_invoice_sent?
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

  def contributor_progress_stage
    return "Won" if status_won?
    return "Lost" if status_lost?
    return "Demo done" if status_demo_completed? || demos.where(status: %i[completed no_show]).exists?
    return "Demo booked" if status_demo_booked? || demos.where(status: %i[scheduled rescheduled]).exists?
    return "Contacted" if status_contacted? || status_qualified?

    "New"
  end

  def contributor_assigned_rep(time = Time.current)
    active_assignment(time)&.user || owner_user
  end

  def contributor_timeline
    timeline_events = []

    contributor_activities.includes(:actor_user).find_each do |activity|
      event = contributor_timeline_event_for(activity)
      timeline_events << event if event.present?
    end

    demos.where(status: %i[completed no_show]).includes(:assigned_to_user).find_each do |demo|
      timeline_events << {
        label: "Demo done",
        occurred_at: demo.updated_at || demo.scheduled_at,
        actor_name: demo.assigned_to_user&.full_name.presence || demo.assigned_to_user&.email_address
      }
    end

    timeline_events.sort_by { |event| event[:occurred_at] || Time.zone.at(0) }.reverse
  end

  private

  def contributor_activities
    activities.where(action_type: %w[
      lead_created_from_submission
      submission_attached
      call_logged
      call_attempt_logged
      demo_booked
      demo_completed
      converted
      status_changed
      lead_status_changed
    ])
  end

  def contributor_timeline_event_for(activity)
    actor_name = activity.actor_user&.full_name.presence || activity.actor_user&.email_address

    case activity.action_type
    when "lead_created_from_submission"
      { label: "Lead created from submission", occurred_at: activity.occurred_at, actor_name: actor_name }
    when "submission_attached"
      { label: "Submission attached to existing lead", occurred_at: activity.occurred_at, actor_name: actor_name }
    when "call_logged", "call_attempt_logged"
      outcome = activity.metadata["outcome"].presence || "unknown"
      { label: "Call logged (#{outcome.to_s.humanize})", occurred_at: activity.occurred_at, actor_name: actor_name }
    when "demo_booked"
      { label: "Demo booked", occurred_at: activity.occurred_at, actor_name: actor_name }
    when "demo_completed"
      { label: "Demo done", occurred_at: activity.occurred_at, actor_name: actor_name }
    when "converted"
      { label: "Lead won", occurred_at: activity.occurred_at, actor_name: actor_name }
    when "status_changed", "lead_status_changed"
      from = activity.metadata["from"].presence || "-"
      to = activity.metadata["to"].presence || activity.metadata["status"].presence || "-"
      { label: "Status changed: #{from.to_s.humanize} -> #{to.to_s.humanize}", occurred_at: activity.occurred_at, actor_name: actor_name }
    end
  end

  def must_have_at_least_one_contact
    return if source.to_s.casecmp("contributor").zero?

    remaining_contacts = lead_contacts.reject(&:marked_for_destruction?)
    errors.add(:lead_contacts, "must include at least one contact") if remaining_contacts.empty?
  end
end
