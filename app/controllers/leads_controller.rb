# frozen_string_literal: true

class LeadsController < ApplicationController
  before_action :set_lead, only: %i[show edit update]
  before_action :load_assignable_users, only: %i[index new create edit update]

  def index
    authorize Lead

    leads_scope = policy_scope(Lead).includes(:owner_user, :lead_contacts)
    leads_scope = apply_filters(leads_scope)
    @leads = set_page_and_extract_portion_from(leads_scope.order(next_action_at: :asc, created_at: :desc))
  end

  def show
    authorize @lead
    @activities = @lead.activities.includes(:actor_user).recent_first
  end

  def new
    authorize Lead
    @lead = Lead.new
    @lead.lead_contacts.build
  end

  def create
    @lead = Lead.new(lead_params)
    @lead.owner_user ||= Current.user
    authorize @lead

    if @lead.save
      write_activity!(@lead, "lead_created", metadata: { status: @lead.status, temperature: @lead.temperature })
      redirect_to @lead, notice: "Lead was successfully created."
    else
      @lead.lead_contacts.build if @lead.lead_contacts.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @lead
    @lead.lead_contacts.build if @lead.lead_contacts.empty?
  end

  def update
    authorize @lead

    if @lead.update(lead_params)
      write_activity!(@lead, "lead_updated", metadata: { changed_fields: @lead.saved_changes.except("updated_at").keys })

      if @lead.saved_change_to_status?
        from, to = @lead.saved_change_to_status
        write_activity!(@lead, "lead_status_changed", metadata: { from: from, to: to })
      end

      redirect_to @lead, notice: "Lead was successfully updated."
    else
      @lead.lead_contacts.build if @lead.lead_contacts.empty?
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_lead
    @lead = Lead.includes(:lead_contacts).find(params[:id])
  end

  def lead_params
    params.require(:lead).permit(
      :business_name,
      :location,
      :industry,
      :source,
      :status,
      :temperature,
      :next_action_at,
      :last_contacted_at,
      :owner_user_id,
      :converted_at,
      lead_contacts_attributes: %i[id name phone email role preferred_channel _destroy]
    )
  end

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

  def write_activity!(lead, action_type, metadata: {})
    Activity.create!(
      actor_user: Current.user,
      subject: lead,
      action_type: action_type,
      metadata: metadata,
      occurred_at: Time.current
    )
  end
end
