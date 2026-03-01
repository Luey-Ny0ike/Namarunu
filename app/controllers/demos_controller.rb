# frozen_string_literal: true

class DemosController < ApplicationController
  before_action :set_demo

  def show
    authorize @demo
    @activities = @demo.activities.includes(:actor_user).recent_first
  end

  def update
    authorize @demo

    previous_status = @demo.status

    Demo.transaction do
      @demo.update!(demo_params)
      write_demo_update_activity!(previous_status)
      sync_lead_status_for_outcome!(previous_status)
    end

    redirect_to @demo, notice: "Demo was successfully updated."
  rescue ActiveRecord::RecordInvalid => e
    @activities = @demo.activities.includes(:actor_user).recent_first
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  private

  def set_demo
    @demo = Demo.includes(:lead, :created_by_user, :assigned_to_user).find(params[:id])
  end

  def demo_params
    params.require(:demo).permit(:status, :outcome, :notes, :demo_link)
  end

  def write_demo_update_activity!(previous_status)
    changed_fields = @demo.saved_changes.except("updated_at").keys
    return if changed_fields.empty?

    Activity.create!(
      actor_user: Current.user,
      subject: @demo,
      action_type: "demo_updated",
      metadata: { changed_fields: changed_fields },
      occurred_at: Time.current
    )

    return unless @demo.saved_change_to_status?

    from, to = @demo.saved_change_to_status
    Activity.create!(
      actor_user: Current.user,
      subject: @demo,
      action_type: "demo_status_changed",
      metadata: { from: from, to: to },
      occurred_at: Time.current
    )
  end

  def sync_lead_status_for_outcome!(previous_status)
    return unless @demo.lead.present?
    return unless @demo.saved_change_to_status?

    lead = @demo.lead

    case @demo.status
    when "completed"
      previous_lead_status = lead.status
      lead.update!(status: :demo_completed, last_contacted_at: Time.current)

      Activity.create!(
        actor_user: Current.user,
        subject: lead,
        action_type: "lead_status_changed",
        metadata: { from: previous_lead_status, to: lead.status, source: "demo_update", demo_id: @demo.id },
        occurred_at: Time.current
      ) if previous_lead_status != lead.status
    when "no_show"
      Activity.create!(
        actor_user: Current.user,
        subject: lead,
        action_type: "demo_status_changed",
        metadata: { from: previous_status, to: @demo.status, demo_id: @demo.id },
        occurred_at: Time.current
      )
    end
  end
end
