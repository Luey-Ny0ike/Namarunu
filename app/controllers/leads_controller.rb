# frozen_string_literal: true

class LeadsController < ApplicationController
  before_action :set_lead, only: %i[show edit update checkout release force_release reassign_checkout]
  before_action :load_assignable_users, only: %i[index show new create edit update reassign_checkout]

  def index
    authorize Lead

    leads_scope = policy_scope(Lead).includes(:owner_user, :lead_contacts)
    leads_scope = apply_filters(leads_scope)
    @leads = set_page_and_extract_portion_from(leads_scope.order(next_action_at: :asc, created_at: :desc))
  end

  def show
    authorize @lead
    @active_assignment = @lead.active_assignment
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

  def checkout
    authorize @lead, :checkout?

    now = Time.current
    active_assignment = nil
    expired_assignments = []
    created_assignment = nil

    Lead.transaction do
      locked_lead = Lead.lock.find(@lead.id)
      expired_assignments = expire_stale_assignments!(locked_lead, now)
      active_assignment = locked_lead.active_assignment(now)

      if active_assignment.blank?
        created_assignment = locked_lead.lead_assignments.create!(
          user: Current.user,
          checked_out_at: now,
          expires_at: now + checkout_duration
        )
        locked_lead.update!(owner_user: Current.user) if locked_lead.owner_user_id.blank?
      end
    end

    write_expired_activities!(@lead, expired_assignments)

    if created_assignment.present?
      write_activity!(@lead, "checked_out", metadata: checkout_activity_metadata(created_assignment))
      redirect_to @lead, notice: "Lead checked out until #{view_context.l(created_assignment.expires_at, format: :short)}."
    else
      holder = user_display_name(active_assignment.user)
      expires_at = view_context.l(active_assignment.expires_at, format: :short)
      redirect_to @lead, alert: "Already checked out by #{holder} until #{expires_at}."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @lead, alert: "Unable to check out lead: #{e.record.errors.full_messages.to_sentence}"
  end

  def release
    authorize @lead, :release?

    now = Time.current
    expired_assignments = []
    released_assignment = nil

    Lead.transaction do
      locked_lead = Lead.lock.find(@lead.id)
      expired_assignments = expire_stale_assignments!(locked_lead, now)
      active_assignment = locked_lead.active_assignment(now)

      if active_assignment.present? && active_assignment.user_id == Current.user.id
        active_assignment.release!(reason: "released", at: now)
        released_assignment = active_assignment
      end
    end

    write_expired_activities!(@lead, expired_assignments)

    if released_assignment.present?
      write_activity!(@lead, "released", metadata: release_activity_metadata(released_assignment, "released"))
      redirect_to @lead, notice: "Lead checkout released."
    else
      redirect_to @lead, alert: "No active checkout found for your user."
    end
  end

  def force_release
    authorize @lead, :force_release?

    now = Time.current
    expired_assignments = []
    released_assignment = nil

    Lead.transaction do
      locked_lead = Lead.lock.find(@lead.id)
      expired_assignments = expire_stale_assignments!(locked_lead, now)
      active_assignment = locked_lead.active_assignment(now)

      if active_assignment.present?
        active_assignment.release!(reason: "force_released", at: now)
        released_assignment = active_assignment
      end
    end

    write_expired_activities!(@lead, expired_assignments)

    if released_assignment.present?
      write_activity!(@lead, "released", metadata: release_activity_metadata(released_assignment, "force_released"))
      redirect_to @lead, notice: "Lead checkout force released."
    else
      redirect_to @lead, alert: "No active checkout to release."
    end
  end

  def reassign_checkout
    authorize @lead, :reassign_checkout?
    assignee = User.find(params.expect(:user_id))

    now = Time.current
    expired_assignments = []
    previous_assignment = nil
    new_assignment = nil

    Lead.transaction do
      locked_lead = Lead.lock.find(@lead.id)
      expired_assignments = expire_stale_assignments!(locked_lead, now)
      previous_assignment = locked_lead.active_assignment(now)

      if previous_assignment.blank? || previous_assignment.user_id != assignee.id
        previous_assignment&.release!(reason: "reassigned", at: now)
        new_assignment = locked_lead.lead_assignments.create!(
          user: assignee,
          checked_out_at: now,
          expires_at: now + checkout_duration
        )
      end

      locked_lead.update!(owner_user: assignee) if locked_lead.owner_user_id.blank?
    end

    write_expired_activities!(@lead, expired_assignments)

    if new_assignment.present?
      write_activity!(
        @lead,
        "reassigned",
        metadata: {
          from_user_id: previous_assignment&.user_id,
          to_user_id: assignee.id,
          expires_at: new_assignment.expires_at.iso8601
        }
      )
      redirect_to @lead, notice: "Lead checkout reassigned to #{user_display_name(assignee)}."
    else
      redirect_to @lead, notice: "Lead is already checked out by #{user_display_name(assignee)}."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to @lead, alert: "User not found."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @lead, alert: "Unable to reassign checkout: #{e.record.errors.full_messages.to_sentence}"
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

  def checkout_duration
    Rails.configuration.x.leads.checkout_duration || 2.hours
  end

  def expire_stale_assignments!(lead, now)
    stale = lead.lead_assignments.unreleased.where("expires_at <= ?", now).to_a
    stale.each { |assignment| assignment.release!(reason: "expired", at: now) }
    stale
  end

  def write_expired_activities!(lead, assignments)
    assignments.each do |assignment|
      write_activity!(
        lead,
        "expired",
        metadata: {
          checked_out_user_id: assignment.user_id,
          expired_at: assignment.expires_at.iso8601
        }
      )
    end
  end

  def checkout_activity_metadata(assignment)
    {
      checked_out_user_id: assignment.user_id,
      expires_at: assignment.expires_at.iso8601
    }
  end

  def release_activity_metadata(assignment, reason)
    {
      checked_out_user_id: assignment.user_id,
      reason: reason,
      released_at: assignment.released_at&.iso8601
    }
  end

  def user_display_name(user)
    user.full_name.presence || user.email_address
  end
end
