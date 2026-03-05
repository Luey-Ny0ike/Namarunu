# frozen_string_literal: true

module App
  class WorkQueueController < App::BaseController
    def pull
      authorize Lead, :work_queue?

      now = Time.current
      result = Leads::SmartPull.new(user: Current.user, count: 10).call
      filtered_ids = valid_queue_ids_in_order(result[:lead_ids], now)
      session[:work_queue_ids] = filtered_ids

      flash[:notice] = if filtered_ids.any?
        "Pulled #{filtered_ids.size} leads into your queue."
      else
        "No eligible leads are available right now."
      end
      flash[:alert] = result[:warning] if result[:warning].present?

      redirect_to app_work_queue_path(lead_id: filtered_ids.first)
    end

    def show
      authorize Lead, :work_queue?

      @queue_ids = queue_ids
      if @queue_ids.empty?
        redirect_to app_root_path, notice: "Queue complete"
        return
      end

      @current_lead = current_lead(@queue_ids)
      @queue_size = @queue_ids.size

      return if @current_lead.blank?

      @current_index = @queue_ids.index(@current_lead.id) || 0
      @prev_lead_id = @current_index.positive? ? @queue_ids[@current_index - 1] : nil
      @next_lead_id = (@current_index < (@queue_ids.size - 1)) ? @queue_ids[@current_index + 1] : nil
      @last_call_attempt = @current_lead.activities
        .where(action_type: "call_logged")
        .order(Arel.sql("COALESCE(occurred_at, created_at) DESC"))
        .first
      @latest_submission = @current_lead.lead_submissions.order(created_at: :desc).first
      @primary_contact = @current_lead.lead_contacts.order(:created_at).first
    end

    private

    def queue_ids
      now = Time.current
      session_ids = Array(session[:work_queue_ids]).map(&:to_i).select(&:positive?).uniq
      if session_ids.any?
        filtered_ids = valid_queue_ids_in_order(session_ids, now)
        session[:work_queue_ids] = filtered_ids
        return filtered_ids
      end

      LeadAssignment.active_at(now)
        .joins(:lead)
        .merge(policy_scope(Lead).where.not(status: [Lead::STATUSES[:won], Lead::STATUSES[:lost]]))
        .where(user_id: Current.user.id)
        .order(checked_out_at: :desc)
        .pluck(:lead_id)
        .tap { |ids| session[:work_queue_ids] = ids if ids.any? }
    end

    def current_lead(ids)
      return if ids.empty?

      requested_id = params[:lead_id].to_i
      current_id = ids.include?(requested_id) ? requested_id : ids.first
      policy_scope(Lead)
        .where(id: current_id)
        .includes(:lead_contacts, :lead_submissions, :activities)
        .find_by(id: current_id)
    end

    def valid_queue_ids_in_order(ids, now)
      normalized_ids = Array(ids).map(&:to_i).select(&:positive?).uniq
      return [] if normalized_ids.empty?

      open_scoped_leads = policy_scope(Lead)
        .where(id: normalized_ids)
        .where.not(status: [Lead::STATUSES[:won], Lead::STATUSES[:lost]])

      open_lead_ids = open_scoped_leads.pluck(:id)
      active_assignment_ids = LeadAssignment
        .active_at(now)
        .joins(:lead)
        .merge(open_scoped_leads)
        .where(user_id: Current.user.id)
        .pluck(:lead_id)

      ids.select { |id| open_lead_ids.include?(id) && active_assignment_ids.include?(id) }
    end
  end
end
