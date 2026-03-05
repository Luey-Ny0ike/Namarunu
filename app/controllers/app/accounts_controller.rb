# frozen_string_literal: true

module App
  class AccountsController < App::BaseController
    def show
      @account = policy_scope(Account).includes(:converted_from_lead, :contacts, demos: %i[assigned_to_user created_by_user]).find(params[:id])
      authorize @account
      @demos = @account.demos.order(scheduled_at: :desc)
    end
  end
end
