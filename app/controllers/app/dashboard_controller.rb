# frozen_string_literal: true

module App
  class DashboardController < App::BaseController
    def show
      now = Time.current
      end_of_day = now.end_of_day
      start_of_day = now.beginning_of_day

      @checked_out_leads = Lead
        .joins(:lead_assignments)
        .merge(LeadAssignment.active_at(now).where(user_id: Current.user.id))
        .distinct
        .includes(:lead_contacts)
      @has_active_queue = @checked_out_leads.exists?

      @todays_demos = Demo
        .where(scheduled_at: start_of_day..end_of_day)
        .where("assigned_to_user_id = :user_id OR created_by_user_id = :user_id", user_id: Current.user.id)
        .includes(:lead, :assigned_to_user)
        .order(:scheduled_at)

      owner_lead_ids = Lead.where(owner_user_id: Current.user.id).select(:id)
      checked_out_lead_ids = Lead
        .joins(:lead_assignments)
        .merge(LeadAssignment.active_at(now).where(user_id: Current.user.id))
        .select(:id)
      active_lead_ids = Lead.where(id: owner_lead_ids).or(Lead.where(id: checked_out_lead_ids)).select(:id)

      @follow_ups_due_today = Lead
        .where(next_action_at: ..end_of_day)
        .where(id: active_lead_ids)
        .includes(:lead_contacts)
        .order(next_action_at: :asc, updated_at: :desc)

      @my_active_leads = Lead
        .left_joins(:activities)
        .where(id: active_lead_ids)
        .includes(:lead_contacts)
        .select("leads.*, MAX(activities.occurred_at) AS last_activity_at")
        .group("leads.id")
        .order(Arel.sql("COALESCE(MAX(activities.occurred_at), leads.updated_at) DESC"))
    end
  end
end
