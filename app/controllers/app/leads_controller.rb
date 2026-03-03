# frozen_string_literal: true

module App
  class LeadsController < BaseController
    before_action :set_lead, only: :show
    before_action :load_assignable_users, only: %i[index show]

    def index
      authorize Lead

      @tab = resolved_tab
      leads_scope = Lead.all
      leads_scope = apply_tab_scope(leads_scope)
      leads_scope = apply_filters(leads_scope)
      leads_scope = leads_scope.preload(:owner_user, :lead_contacts)
      @leads = set_page_and_extract_portion_from(leads_scope.order(next_action_at: :asc, created_at: :desc))
      @show_all_tab = manager_like?
      @show_owner_filter = manager_like?

      render "leads/index"
    end

    def show
      authorize @lead
      @active_assignment = @lead.active_assignment
      @latest_submission = @lead.lead_submissions.order(created_at: :desc, id: :desc).first
      @activities = @lead.activities.includes(:actor_user).recent_first
      @demos = policy_scope(Demo).where(lead_id: @lead.id).order(scheduled_at: :asc)

      render "leads/show"
    end

    private

    def set_lead
      @lead = Lead.includes(:lead_contacts, :converted_account, :lead_submissions).find(params[:id])
    end

    def resolved_tab
      params[:tab].presence_in(allowed_tabs) || default_tab
    end

    def default_tab
      manager_like? ? "all" : "my"
    end

    def allowed_tabs
      return %w[my unassigned followups all] if manager_like?

      %w[my unassigned followups]
    end

    def apply_tab_scope(scope)
      if manager_like?
        return scope.follow_ups_due if @tab == "followups"

        return scope
      end

      case @tab
      when "unassigned"
        scope.where(owner_user_id: nil)
      when "followups"
        scope.follow_ups_due.where(owner_user_id: [Current.user.id, nil])
      when "my"
        if params[:tab].blank?
          scope.where(owner_user_id: [Current.user.id, nil])
        else
          scope.where(owner_user_id: Current.user.id)
        end
      else
        scope.where(owner_user_id: [Current.user.id, nil])
      end
    end

    def apply_filters(scope)
      filtered = scope
      filtered = filtered.where(status: params[:status]) if params[:status].present?
      filtered = filtered.where(temperature: params[:temperature]) if params[:temperature].present?
      filtered = filtered.where(owner_user_id: params[:owner_user_id]) if manager_like? && params[:owner_user_id].present?
      filtered = filtered.follow_ups_due if params[:follow_ups_due] == "1"
      filtered = apply_search(filtered) if params[:q].present?
      filtered
    end

    def apply_search(scope)
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)}%"

      scope
        .left_outer_joins(:lead_contacts, :lead_submissions)
        .where(
          "LOWER(leads.business_name) LIKE :query OR LOWER(lead_contacts.phone) LIKE :query OR LOWER(lead_submissions.instagram_handle) LIKE :query",
          query: query
        )
        .distinct
    end

    def load_assignable_users
      @assignable_users = User.order(:full_name, :email_address)
    end

    def manager_like?
      Current.user&.sales_manager? || Current.user&.super_admin?
    end
  end
end
