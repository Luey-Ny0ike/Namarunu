# frozen_string_literal: true

module Leads
  class SmartPull
    DEFAULT_COUNT = 10
    ACTIVE_ASSIGNMENT_WARNING_THRESHOLD = 30
    RECENT_ACTIVITY_WINDOW = 24.hours
    CHECKOUT_DURATION = 2.hours

    attr_reader :user, :count

    def initialize(user:, count: DEFAULT_COUNT)
      @user = user
      @count = count.to_i.positive? ? count.to_i : DEFAULT_COUNT
    end

    def call
      now = Time.current
      warning = warning_message(now)
      selected_ids = selected_lead_ids(now)
      pulled_ids = []

      Lead.transaction do
        selected_ids.each do |lead_id|
          lead = Lead.lock.find(lead_id)
          release_stale_unreleased_assignments!(lead, now)
          next if lead.lead_assignments.unreleased.exists?

          assignment = LeadAssignment.create!(
            lead: lead,
            user: user,
            checked_out_at: now,
            expires_at: now + CHECKOUT_DURATION
          )
          Activity.create!(
            actor_user: user,
            subject: lead,
            action_type: "checked_out",
            metadata: {
              checked_out_user_id: user.id,
              expires_at: assignment.expires_at.iso8601
            },
            occurred_at: now
          )

          pulled_ids << lead.id
        end
      end

      { lead_ids: pulled_ids, warning: warning }
    end

    private

    def selected_lead_ids(now)
      recent_activity_lead_ids = Activity
        .where(subject_type: "Lead")
        .where(occurred_at: (now - RECENT_ACTIVITY_WINDOW)..)
        .distinct
        .pluck(:subject_id)

      fresh_contributor_ids = contributor_pool_scope(now)
        .where.not(id: recent_activity_lead_ids)
        .order(created_at: :desc)
        .limit(count)
        .pluck(:id)
      remaining = count - fresh_contributor_ids.size

      fresh_other_ids = if remaining.positive?
        other_pool_scope(now)
          .where.not(id: recent_activity_lead_ids)
          .order(created_at: :desc)
          .limit(remaining)
          .pluck(:id)
      else
        []
      end
      remaining -= fresh_other_ids.size

      recent_contributor_ids = if remaining.positive?
        contributor_pool_scope(now)
          .where(id: recent_activity_lead_ids)
          .order(created_at: :desc)
          .limit(remaining)
          .pluck(:id)
      else
        []
      end
      remaining -= recent_contributor_ids.size

      recent_other_ids = if remaining.positive?
        other_pool_scope(now)
          .where(id: recent_activity_lead_ids)
          .order(created_at: :desc)
          .limit(remaining)
          .pluck(:id)
      else
        []
      end

      (fresh_contributor_ids + fresh_other_ids + recent_contributor_ids + recent_other_ids).uniq
    end

    def eligible_pool_scope(now)
      active_assignment_lead_ids = LeadAssignment.active_at(now).select(:lead_id)

      Lead
        .where(owner_user_id: nil)
        .where.not(status: [Lead::STATUSES[:lost], Lead::STATUSES[:won]])
        .where.not(id: active_assignment_lead_ids)
    end

    def contributor_pool_scope(now)
      eligible_pool_scope(now).where(source: "contributor")
    end

    def other_pool_scope(now)
      eligible_pool_scope(now).where.not(source: "contributor")
    end

    def warning_message(now)
      active_count = LeadAssignment.active_at(now).where(user_id: user.id).count
      return if active_count <= ACTIVE_ASSIGNMENT_WARNING_THRESHOLD

      "You currently have #{active_count} active leads checked out."
    end

    def release_stale_unreleased_assignments!(lead, now)
      stale_assignments = lead.lead_assignments.unreleased.where("expires_at <= ?", now)
      stale_assignments.find_each do |assignment|
        assignment.release!(reason: "expired", at: now)
      end
    end
  end
end
