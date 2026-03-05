# frozen_string_literal: true

module App
  class LeadActionsController < App::BaseController
    WON_ALLOWED_STATUSES = %w[
      demo_completed
      awaiting_commitment
      invoice_sent
      won
    ].freeze

    def confirm_payment
      lead = Lead.find(params[:id])
      authorize lead, :update?

      unless WON_ALLOWED_STATUSES.include?(lead.status)
        redirect_to failure_redirect_target, alert: "Lead can only be marked won from Demo completed or later stages."
        return
      end

      now = Time.current
      Lead.transaction do
        account = LeadConverter.call(lead, actor_user: Current.user)

        lead.update!(status: :won)
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "won",
          metadata: {
            account_id: account&.id,
            source: "confirm_payment"
          }.compact,
          occurred_at: now
        )
        remove_from_queue!(lead.id)
      end

      redirect_to success_redirect_target, notice: "Payment confirmed. Lead marked as won."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to confirm payment: #{e.record.errors.full_messages.to_sentence}"
    end

    def release_and_next
      lead = Lead.find(params[:id])
      authorize lead, :release?

      now = Time.current
      active_assignment = lead.active_assignment(now)
      if active_assignment.blank?
        redirect_to failure_redirect_target, alert: "No active checkout to release."
        return
      end

      active_assignment.release!(reason: "released", at: now)
      remove_from_queue!(lead.id)

      next_id = params[:queue_next_lead_id].to_i
      queue_ids = Array(session[:work_queue_ids]).map(&:to_i).select(&:positive?)
      if queue_ids.empty?
        redirect_to app_root_path, notice: "Queue complete"
      elsif next_id.positive?
        redirect_to app_work_queue_path(lead_id: next_id), notice: "Lead released."
      else
        redirect_to app_work_queue_path(lead_id: queue_ids.first), notice: "Lead released."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to release lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def convert
      lead = Lead.find(params[:id])
      authorize lead, :convert?

      account = nil
      lead_status = lead.status
      now = Time.current

      Lead.transaction do
        account = Account.create!(
          name: lead.business_name,
          converted_from_lead: lead
        )

        primary_contact = lead.lead_contacts.order(:created_at, :id).first
        Contact.create!(
          account: account,
          name: primary_contact&.name.presence || "Primary Contact",
          phone: primary_contact&.phone,
          email: primary_contact&.email,
          role: primary_contact&.role
        )

        lead_updates = { converted_at: now }
        lead_updates[:status] = :demo_booked if lead.demos.exists? && lead.status_qualified?
        lead.update!(lead_updates)
        lead.demos.where(account_id: nil).update_all(account_id: account.id)

        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "converted",
          metadata: {
            account_id: account.id,
            previous_status: lead_status,
            status: lead.status
          },
          occurred_at: now
        )
      end

      redirect_to app_account_path(account), notice: "Lead converted to account successfully."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to convert lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def checkout
      lead = Lead.find(params[:id])
      authorize lead, :checkout?

      now = Time.current
      active_assignment = nil
      expired_assignments = []
      created_assignment = nil

      Lead.transaction do
        locked_lead = Lead.lock.find(lead.id)
        expired_assignments = expire_stale_assignments!(locked_lead, now)
        active_assignment = locked_lead.active_assignment(now)

        if active_assignment.blank?
          created_assignment = locked_lead.lead_assignments.create!(
            user: Current.user,
            checked_out_at: now,
            expires_at: now + checkout_duration
          )
        end
      end

      write_expired_activities!(lead, expired_assignments)

      if created_assignment.present?
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "checked_out",
          metadata: checkout_activity_metadata(created_assignment),
          occurred_at: now
        )
        redirect_to success_redirect_target, notice: "Lead checked out until #{view_context.l(created_assignment.expires_at, format: :short)}."
      else
        holder = user_display_name(active_assignment.user)
        expires_at = view_context.l(active_assignment.expires_at, format: :short)
        redirect_to failure_redirect_target, alert: "Already checked out by #{holder} until #{expires_at}."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to check out lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def release
      lead = Lead.find(params[:id])
      authorize lead, :release?

      now = Time.current
      expired_assignments = []
      released_assignment = nil

      Lead.transaction do
        locked_lead = Lead.lock.find(lead.id)
        expired_assignments = expire_stale_assignments!(locked_lead, now)
        active_assignment = locked_lead.active_assignment(now)

        if active_assignment.present? && active_assignment.user_id == Current.user.id
          active_assignment.release!(reason: "released", at: now)
          released_assignment = active_assignment
        end
      end

      write_expired_activities!(lead, expired_assignments)

      if released_assignment.present?
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "released",
          metadata: release_activity_metadata(released_assignment, "released"),
          occurred_at: now
        )
        redirect_to success_redirect_target, notice: "Lead checkout released."
      else
        redirect_to failure_redirect_target, alert: "No active checkout found for your user."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to release lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def force_release
      lead = Lead.find(params[:id])
      authorize lead, :force_release?

      now = Time.current
      expired_assignments = []
      released_assignment = nil

      Lead.transaction do
        locked_lead = Lead.lock.find(lead.id)
        expired_assignments = expire_stale_assignments!(locked_lead, now)
        active_assignment = locked_lead.active_assignment(now)

        if active_assignment.present?
          active_assignment.release!(reason: "force_released", at: now)
          released_assignment = active_assignment
        end
      end

      write_expired_activities!(lead, expired_assignments)

      if released_assignment.present?
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "released",
          metadata: release_activity_metadata(released_assignment, "force_released"),
          occurred_at: now
        )
        redirect_to success_redirect_target, notice: "Lead checkout force released."
      else
        redirect_to failure_redirect_target, alert: "No active checkout to release."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to force release lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def reassign_checkout
      lead = Lead.find(params[:id])
      authorize lead, :reassign_checkout?
      assignee = User.find(reassign_checkout_params[:user_id])

      now = Time.current
      expired_assignments = []
      previous_assignment = nil
      new_assignment = nil

      Lead.transaction do
        locked_lead = Lead.lock.find(lead.id)
        expired_assignments = expire_stale_assignments!(locked_lead, now)
        previous_assignment = locked_lead.active_assignment(now)

        if previous_assignment.blank? || previous_assignment.user_id != assignee.id
          previous_assignment&.release!(reason: "reassigned", at: now)
          new_assignment = locked_lead.lead_assignments.create!(
            user: assignee,
            checked_out_at: now,
            expires_at: now + checkout_duration
          )
        end
      end

      write_expired_activities!(lead, expired_assignments)

      if new_assignment.present?
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "reassigned",
          metadata: {
            from_user_id: previous_assignment&.user_id,
            to_user_id: assignee.id,
            expires_at: new_assignment.expires_at.iso8601
          },
          occurred_at: now
        )
        redirect_to success_redirect_target, notice: "Lead checkout reassigned to #{user_display_name(assignee)}."
      else
        redirect_to success_redirect_target, notice: "Lead is already checked out by #{user_display_name(assignee)}."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to failure_redirect_target, alert: "User not found."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to reassign checkout: #{e.record.errors.full_messages.to_sentence}"
    end

    def mark_awaiting_commitment
      lead = Lead.find(params[:id])
      authorize lead, :update?

      now = Time.current
      Lead.transaction do
        LeadConverter.call(lead, actor_user: Current.user)

        previous_status = lead.status
        lead.update!(status: :awaiting_commitment)
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "status_changed",
          metadata: { from: previous_status, to: lead.status },
          occurred_at: now
        )
      end

      redirect_to success_redirect_target, notice: "Lead moved to awaiting commitment."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to update lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def mark_invoice_sent
      lead = Lead.find(params[:id])
      authorize lead, :update?

      now = Time.current
      Lead.transaction do
        LeadConverter.call(lead, actor_user: Current.user)

        lead.update!(status: :invoice_sent, invoice_sent_at: now)
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "invoice_sent",
          metadata: { invoice_sent_at: now.iso8601 },
          occurred_at: now
        )
      end

      redirect_to success_redirect_target, notice: "Invoice marked as sent."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to update lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def mark_lost
      lead = Lead.find(params[:id])
      authorize lead, :update?

      lost_reason = post_demo_params[:lost_reason].to_s
      if lost_reason.blank?
        redirect_to failure_redirect_target, alert: "Lost reason is required."
        return
      end

      now = Time.current
      Lead.transaction do
        lead.update!(status: :lost, lost_reason: lost_reason)
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "lost",
          metadata: { lost_reason: lost_reason },
          occurred_at: now
        )

        active_assignment = lead.active_assignment(now)
        active_assignment&.release!(reason: "lost", at: now)
        remove_from_queue!(lead.id)
      end

      redirect_to success_redirect_target, notice: "Lead marked as lost."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to update lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def book_demo
      lead = Lead.find(params[:id])
      authorize lead, :update?

      scheduled_at = parse_datetime(book_demo_params[:scheduled_at])
      if scheduled_at.blank?
        redirect_to safe_return_to || app_lead_path(lead), alert: "Scheduled time is required."
        return
      end

      now = Time.current
      demo = nil
      assigned_user = assignee_for_booking(book_demo_params[:assigned_to_user_id])

      Lead.transaction do
        demo = Demo.create!(
          lead: lead,
          scheduled_at: scheduled_at,
          duration_minutes: book_demo_params[:duration_minutes].presence || 30,
          notes: book_demo_params[:notes].to_s.strip.presence,
          assigned_to_user: assigned_user,
          created_by_user: Current.user
        )

        lead.update!(status: :demo_booked, next_action_at: scheduled_at)
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "demo_booked",
          metadata: {
            demo_id: demo.id,
            scheduled_at: demo.scheduled_at.iso8601,
            duration_minutes: demo.duration_minutes
          },
          occurred_at: now
        )
      end

      redirect_to safe_return_to || app_lead_path(lead), notice: "Demo booked."
    rescue ActiveRecord::RecordNotFound
      redirect_to safe_return_to || app_lead_path(lead), alert: "Assignee not found."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to safe_return_to || app_lead_path(params[:id]), alert: "Unable to book demo: #{e.record.errors.full_messages.to_sentence}"
    end

    def log_attempt
      lead = Lead.find(params[:id])
      authorize lead, :update?

      outcome = log_attempt_params[:outcome].to_s
      notes = log_attempt_params[:notes].to_s
      next_action_at = parse_datetime(log_attempt_params[:next_action_at])

      unless Lead::CALL_OUTCOMES.value?(outcome)
        redirect_to failure_redirect_target, alert: "Invalid call outcome."
        return
      end

      if Lead.follow_up_outcome?(outcome) && next_action_at.blank?
        redirect_to failure_redirect_target, alert: "Follow-up date is required when outcome is Follow up."
        return
      end

      now = Time.current
      updates = {
        last_contacted_at: now,
        status: Lead.call_outcome_status_transition(outcome)
      }.compact
      updates[:lost_reason] = inferred_lost_reason(outcome) if updates[:status] == Lead::STATUSES[:lost] && lead.lost_reason.blank?
      updates[:next_action_at] = next_action_at if Lead.follow_up_outcome?(outcome)

      Lead.transaction do
        lead.update!(updates)
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "call_logged",
          metadata: {
            outcome: outcome,
            notes: notes.presence,
            next_action_at: next_action_at&.iso8601
          }.compact,
          occurred_at: now
        )

        remove_from_queue!(lead.id) if lead.status_lost? || lead.status_won?
      end

      redirect_to success_redirect_target, notice: "Call logged."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to log call attempt: #{e.record.errors.full_messages.to_sentence}"
    end

    private

    def log_attempt_params
      params.permit(:outcome, :notes, :next_action_at, :return_to, :queue_next_lead_id)
    end

    def book_demo_params
      params.permit(:scheduled_at, :duration_minutes, :notes, :assigned_to_user_id, :return_to)
    end

    def post_demo_params
      params.permit(:lost_reason, :return_to, :queue_next_lead_id)
    end

    def reassign_checkout_params
      params.permit(:user_id, :return_to, :queue_next_lead_id)
    end

    def parse_datetime(raw_value)
      return if raw_value.blank?

      Time.zone.parse(raw_value.to_s)
    rescue ArgumentError
      nil
    end

    def inferred_lost_reason(outcome)
      case outcome.to_s
      when "wrong_number"
        Lead::LOST_REASONS[:invalid_contact]
      when "not_interested"
        Lead::LOST_REASONS[:not_a_fit]
      else
        Lead::LOST_REASONS[:other]
      end
    end

    def remove_from_queue!(lead_id)
      queue_ids = Array(session[:work_queue_ids]).map(&:to_i)
      updated_ids = queue_ids - [lead_id.to_i]
      session[:work_queue_ids] = updated_ids
    end

    def success_redirect_target
      next_id = params[:queue_next_lead_id].to_i
      return app_work_queue_path(lead_id: next_id) if next_id.positive?

      safe_return_to || app_lead_path(params[:id])
    end

    def failure_redirect_target
      safe_return_to || app_lead_path(params[:id])
    end

    def safe_return_to
      path = params[:return_to].to_s
      return if path.blank?
      return unless path.start_with?("/")

      path
    end

    def assignee_for_booking(requested_assignee_id)
      return Current.user if requested_assignee_id.blank?
      return Current.user if Current.user&.sales_rep?

      User.find(requested_assignee_id)
    end

    def checkout_duration
      Rails.configuration.x.leads.checkout_duration || 2.hours
    end

    def expire_stale_assignments!(lead, now)
      stale = lead.lead_assignments.unreleased.where("expires_at <= ?", now).to_a
      stale.each { |assignment| assignment.release!(reason: "expired", at: now) }
      stale
    end

    def write_expired_activities!(lead, assignments)
      assignments.each do |assignment|
        Activity.create!(
          actor_user: Current.user,
          subject: lead,
          action_type: "expired",
          metadata: {
            checked_out_user_id: assignment.user_id,
            expired_at: assignment.expires_at.iso8601
          },
          occurred_at: Time.current
        )
      end
    end

    def checkout_activity_metadata(assignment)
      {
        checked_out_user_id: assignment.user_id,
        expires_at: assignment.expires_at.iso8601
      }
    end

    def release_activity_metadata(assignment, reason)
      {
        checked_out_user_id: assignment.user_id,
        reason: reason,
        released_at: assignment.released_at&.iso8601
      }
    end

    def user_display_name(user)
      user.full_name.presence || user.email_address
    end
  end
end
