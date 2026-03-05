# frozen_string_literal: true

module App
  class CustomersController < App::BaseController
    before_action :set_customer, only: %i[show update]
    before_action :load_form_collections, only: %i[new create show]

    def index
      authorize Account, :index?

      @status_filter = resolved_status_filter
      @query = params[:q].to_s.strip

      customers = policy_scope(Account)
      customers = customers.where(status: @status_filter)
      customers = customers.where("LOWER(accounts.name) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%") if @query.present?

      @customers = customers.includes(:owner_user, :converted_from_lead).order(updated_at: :desc)
    end

    def new
      authorize Account, :create?

      @customer = Account.new(status: :pending)
      @customer.owner_user = Current.user if Current.user&.sales_rep?
      @customer.contacts.build
      @industry_options = industry_options(@customer)
    end

    def create
      @customer = Account.new(customer_create_params)
      authorize @customer, :create?

      @customer.status = :pending if @customer.status.blank?
      @customer.owner_user ||= Current.user

      if @customer.save
        redirect_to app_customer_path(@customer), notice: "Customer created."
      else
        @customer.contacts.build if @customer.contacts.empty?
        @industry_options = industry_options(@customer)
        render :new, status: :unprocessable_entity
      end
    end

    def show
      authorize @customer, :show?
      @lead = @customer.converted_from_lead
      @contacts = @customer.contacts.order(created_at: :asc, id: :asc)
      @industry_options = industry_options(@customer)
    end

    def update
      authorize @customer, :update?

      if @customer.update(customer_update_params)
        redirect_to app_customer_path(@customer), notice: "Customer updated."
      else
        @lead = @customer.converted_from_lead
        @contacts = @customer.contacts.order(created_at: :asc, id: :asc)
        @industry_options = industry_options(@customer)
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_customer
      @customer = policy_scope(Account).includes(:converted_from_lead, :contacts).find(params[:id])
    end

    def load_form_collections
      @assignable_users = User.order(:full_name, :email_address) if manager_or_admin?
    end

    def manager_or_admin?
      Current.user&.sales_manager? || Current.user&.super_admin?
    end

    def resolved_status_filter
      status = params[:status].to_s
      return "active" if status == "active"
      return "cancelled" if status == "cancelled"

      "pending"
    end

    def industry_options(customer)
      base = Lead::INDUSTRIES.values
      return base if customer.industry.blank? || base.include?(customer.industry)

      base + [customer.industry]
    end

    def customer_base_params
      [
        :name,
        :industry,
        :location,
        :instagram_handle,
        :instagram_url,
        :tiktok_handle,
        :tiktok_url,
        :facebook_url,
        :status,
        contacts_attributes: %i[id name phone email role _destroy]
      ]
    end

    def customer_create_params
      permitted = customer_base_params.dup
      permitted << :owner_user_id if manager_or_admin?

      params.require(:account).permit(permitted)
    end

    def customer_update_params
      permitted = customer_base_params.dup
      permitted << :owner_user_id if manager_or_admin?

      params.require(:account).permit(permitted)
    end
  end
end
