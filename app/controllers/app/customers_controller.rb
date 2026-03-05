# frozen_string_literal: true

module App
  class CustomersController < App::BaseController
    before_action :set_customer, only: %i[show update]

    def index
      authorize Account, :index?

      @status_filter = resolved_status_filter
      @query = params[:q].to_s.strip

      customers = policy_scope(Account)
      customers = customers.where(status: @status_filter)
      customers = customers.where("LOWER(accounts.name) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%") if @query.present?

      @customers = customers.includes(:owner_user, :converted_from_lead).order(updated_at: :desc)
    end

    def show
      authorize @customer, :show?
      @lead = @customer.converted_from_lead
      @contacts = @customer.contacts.order(created_at: :asc, id: :asc)
      @industry_options = industry_options
    end

    def update
      authorize @customer, :update?

      if @customer.update(customer_params)
        redirect_to app_customer_path(@customer), notice: "Customer updated."
      else
        @lead = @customer.converted_from_lead
        @contacts = @customer.contacts.order(created_at: :asc, id: :asc)
        @industry_options = industry_options
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_customer
      @customer = policy_scope(Account).includes(:converted_from_lead, :contacts).find(params[:id])
    end

    def resolved_status_filter
      status = params[:status].to_s
      return "active" if status == "active"
      return "cancelled" if status == "cancelled"

      "pending"
    end

    def industry_options
      base = Lead::INDUSTRIES.values
      return base if @customer.industry.blank? || base.include?(@customer.industry)

      base + [@customer.industry]
    end

    def customer_params
      params.require(:account).permit(
        :industry,
        :location,
        :instagram_handle,
        :instagram_url,
        :tiktok_handle,
        :tiktok_url,
        :facebook_url
      )
    end
  end
end
