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
        account = ensure_converted_account!(lead, now)

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

    def mark_awaiting_commitment
      lead = Lead.find(params[:id])
      authorize lead, :update?

      previous_status = lead.status
      lead.update!(status: :awaiting_commitment)
      Activity.create!(
        actor_user: Current.user,
        subject: lead,
        action_type: "status_changed",
        metadata: { old: previous_status, new: lead.status },
        occurred_at: Time.current
      )

      redirect_to success_redirect_target, notice: "Lead moved to awaiting commitment."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to update lead: #{e.record.errors.full_messages.to_sentence}"
    end

    def mark_invoice_sent
      lead = Lead.find(params[:id])
      authorize lead, :update?

      now = Time.current
      lead.update!(status: :invoice_sent, invoice_sent_at: now)
      Activity.create!(
        actor_user: Current.user,
        subject: lead,
        action_type: "invoice_sent",
        metadata: { invoice_sent_at: now.iso8601 },
        occurred_at: now
      )

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
        redirect_to safe_return_to || lead_path(lead), alert: "Scheduled time is required."
        return
      end

      now = Time.current
      demo = nil

      Lead.transaction do
        demo = Demo.create!(
          lead: lead,
          scheduled_at: scheduled_at,
          duration_minutes: book_demo_params[:duration_minutes].presence || 30,
          notes: book_demo_params[:notes].to_s.strip.presence,
          assigned_to_user: Current.user,
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

      redirect_to app_demos_path(tab: "upcoming"), notice: "Demo booked."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to safe_return_to || lead_path(params[:id]), alert: "Unable to book demo: #{e.record.errors.full_messages.to_sentence}"
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
            notes_present: notes.present?
          },
          occurred_at: now
        )

        remove_from_queue!(lead.id) if lead.status_lost? || lead.status_won?
      end

      redirect_to success_redirect_target, notice: "Call attempt logged."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to failure_redirect_target, alert: "Unable to log call attempt: #{e.record.errors.full_messages.to_sentence}"
    end

    private

    def log_attempt_params
      params.permit(:outcome, :notes, :next_action_at, :return_to, :queue_next_lead_id)
    end

    def book_demo_params
      params.permit(:scheduled_at, :duration_minutes, :notes, :return_to)
    end

    def post_demo_params
      params.permit(:lost_reason, :return_to, :queue_next_lead_id)
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

    def ensure_converted_account!(lead, now)
      return lead.converted_account if lead.converted_account.present?

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

      lead.update!(converted_at: now)
      lead.demos.where(account_id: nil).update_all(account_id: account.id)

      Activity.create!(
        actor_user: Current.user,
        subject: lead,
        action_type: "converted",
        metadata: {
          account_id: account.id,
          source: "confirm_payment"
        },
        occurred_at: now
      )

      account
    end

    def success_redirect_target
      next_id = params[:queue_next_lead_id].to_i
      return app_work_queue_path(lead_id: next_id) if next_id.positive?

      safe_return_to || lead_path(params[:id])
    end

    def failure_redirect_target
      safe_return_to || lead_path(params[:id])
    end

    def safe_return_to
      path = params[:return_to].to_s
      return if path.blank?
      return unless path.start_with?("/")

      path
    end
  end
end
