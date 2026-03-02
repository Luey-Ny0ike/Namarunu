# frozen_string_literal: true

module App
  class LeadsController < BaseController
    before_action :load_assignable_users, only: :index

    def index
      authorize Lead

      leads_scope = policy_scope(Lead).includes(:owner_user, :lead_contacts)
      leads_scope = apply_filters(leads_scope)
      @leads = set_page_and_extract_portion_from(leads_scope.order(next_action_at: :asc, created_at: :desc))

      render "leads/index"
    end

    private

    def apply_filters(scope)
      filtered = scope
      filtered = filtered.where(status: params[:status]) if params[:status].present?
      filtered = filtered.where(temperature: params[:temperature]) if params[:temperature].present?
      filtered = filtered.where(owner_user_id: params[:owner_user_id]) if params[:owner_user_id].present?
      filtered = filtered.follow_ups_due if params[:follow_ups_due] == "1"
      filtered
    end

    def load_assignable_users
      @assignable_users = User.order(:full_name, :email_address)
    end
  end
end
