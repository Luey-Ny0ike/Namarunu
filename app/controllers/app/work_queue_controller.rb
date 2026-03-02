# frozen_string_literal: true

module App
  class WorkQueueController < App::BaseController
    def pull
      result = Leads::SmartPull.new(user: Current.user, count: 10).call
      session[:work_queue_ids] = result[:lead_ids]

      flash[:notice] = if result[:lead_ids].any?
        "Pulled #{result[:lead_ids].size} leads into your queue."
      else
        "No eligible leads are available right now."
      end
      flash[:alert] = result[:warning] if result[:warning].present?

      redirect_to app_work_queue_path(lead_id: result[:lead_ids].first)
    end

    def show
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
      @last_call_attempt = @current_lead.activities.where(action_type: "call_attempt_logged").recent_first.first
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

      LeadAssignment.active_at
        .joins(:lead)
        .where(user_id: Current.user.id)
        .where.not(leads: { status: [Lead::STATUSES[:won], Lead::STATUSES[:lost]] })
        .order(checked_out_at: :desc)
        .pluck(:lead_id)
        .tap { |ids| session[:work_queue_ids] = ids if ids.any? }
    end

    def current_lead(ids)
      return if ids.empty?

      requested_id = params[:lead_id].to_i
      current_id = ids.include?(requested_id) ? requested_id : ids.first
      Lead.includes(:lead_contacts, :lead_submissions, :activities).find_by(id: current_id)
    end

    def valid_queue_ids_in_order(ids, now)
      open_lead_ids = Lead.where(id: ids).where.not(status: [Lead::STATUSES[:won], Lead::STATUSES[:lost]]).pluck(:id)
      active_assignment_ids = LeadAssignment
        .active_at(now)
        .where(user_id: Current.user.id, lead_id: ids)
        .pluck(:lead_id)

      ids.select { |id| open_lead_ids.include?(id) && active_assignment_ids.include?(id) }
    end
  end
end
