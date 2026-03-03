# frozen_string_literal: true

module App
  class DemosController < App::BaseController
    def show
      @demo = Demo.includes(:lead, :created_by_user, :assigned_to_user).find(params[:id])
      authorize @demo
      @activities = @demo.activities.includes(:actor_user).recent_first

      render "demos/show"
    end

    def index
      authorize Demo

      now = Time.current
      @tab = params[:tab].presence_in(%w[today upcoming past]) || "today"

      base_scope = policy_scope(Demo).includes(:lead, :assigned_to_user, :created_by_user)
      base_scope = base_scope.where(assigned_to_user_id: params[:assigned_to_user_id]) if manager_like? && params[:assigned_to_user_id].present?
      base_scope = base_scope.where(assigned_to_user_id: Current.user.id) unless manager_like?

      @demos = case @tab
      when "upcoming"
        base_scope.where("scheduled_at > ?", now.end_of_day).order(scheduled_at: :asc)
      when "past"
        base_scope.where("scheduled_at < ?", now.beginning_of_day).order(scheduled_at: :desc)
      else
        base_scope.where(scheduled_at: now.beginning_of_day..now.end_of_day).order(scheduled_at: :asc)
      end
    end

    def complete
      demo = Demo.includes(:lead).find(params[:id])
      authorize demo, :update?

      completion_status = complete_params[:status].to_s
      unless %w[completed no_show].include?(completion_status)
        redirect_to app_demos_path(tab: "today"), alert: "Status must be completed or no_show."
        return
      end

      Demo.transaction do
        demo.update!(
          status: completion_status,
          outcome: complete_params[:outcome].presence,
          notes: complete_params[:notes].to_s.strip.presence
        )
        if demo.lead.present?
          demo.lead.update!(status: :demo_completed)
          Activity.create!(
            actor_user: Current.user,
            subject: demo.lead,
            action_type: "demo_completed",
            metadata: {
              demo_id: demo.id,
              status: demo.status,
              outcome: demo.outcome
            },
            occurred_at: Time.current
          )
        end
      end

      redirect_to app_demos_path(tab: "today"), notice: "Demo updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to app_demos_path(tab: "today"), alert: "Unable to complete demo: #{e.record.errors.full_messages.to_sentence}"
    end

    private

    def complete_params
      params.permit(:status, :outcome, :notes)
    end

    def manager_like?
      Current.user&.sales_manager? || Current.user&.super_admin?
    end
  end
end
