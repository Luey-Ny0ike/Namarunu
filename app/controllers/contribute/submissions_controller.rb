# frozen_string_literal: true

module Contribute
  class SubmissionsController < BaseController
    before_action :set_submission, only: %i[show edit update]
    helper_method :lead_progress_label, :lead_progress_badge_class, :submission_result_badge_class, :time_left_in_words

    def index
      authorize LeadSubmission
      scoped = policy_scope(LeadSubmission).includes(lead: %i[owner_user lead_assignments]).order(created_at: :desc)
      @submissions = set_page_and_extract_portion_from(scoped)
    end

    def show
      authorize @submission
      @linked_lead = @submission.lead
      @active_assignment = @linked_lead&.active_assignment
      @assigned_rep = @active_assignment&.user || @linked_lead&.owner_user
    end

    def new
      @submission = LeadSubmission.new(preview_submission_params)
      authorize @submission
      @possible_duplicate = preview_duplicate_for(@submission)
    end

    def create
      @submission = LeadSubmission.new(submission_params.merge(submitted_by_user: Current.user))
      authorize @submission

      matcher = LeadSubmissionMatcher.new(@submission)
      matcher.call

      notice =
        if matcher.attached_to_existing_lead?
          "Submission received. Attached to existing lead."
        else
          "Submission received. Created a new lead."
        end

      redirect_to contribute_submission_path(@submission), notice: notice
    rescue ActiveRecord::RecordInvalid
      @possible_duplicate = preview_duplicate_for(@submission)
      flash.now[:alert] = "Please review the highlighted fields."
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @submission
      return if @submission.editable_now?

      redirect_to contribute_submission_path(@submission), alert: "Locked: this submission can no longer be edited."
    end

    def update
      authorize @submission

      unless @submission.editable_now?
        redirect_to contribute_submission_path(@submission), alert: "Locked: this submission can no longer be edited."
        return
      end

      if @submission.update(submission_params)
        redirect_to contribute_submission_path(@submission), notice: "Submission updated successfully."
      else
        flash.now[:alert] = "Please review the highlighted fields."
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_submission
      @submission = LeadSubmission.find(params[:id])
    end

    def submission_params
      params.require(:lead_submission).permit(
        :business_name,
        :instagram_url,
        :tiktok_url,
        :phone_raw,
        :location,
        :notes
      )
    end

    def preview_submission_params
      params.fetch(:lead_submission, {}).permit(
        :business_name,
        :instagram_url,
        :tiktok_url,
        :phone_raw,
        :location,
        :notes
      )
    end

    def preview_duplicate_for(submission)
      return if submission.business_name.blank? && submission.instagram_url.blank? && submission.tiktok_url.blank? && submission.phone_raw.blank?

      matcher = LeadSubmissionMatcher.new(submission)
      matcher.preview_match
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def lead_progress_label(lead)
      return "Unmatched" if lead.blank?

      lead.status.to_s.humanize
    end

    def lead_progress_badge_class(lead)
      return "bg-secondary" if lead.blank?

      case lead.status.to_s
      when "new"
        "bg-secondary"
      when "in_progress", "contacted"
        "bg-info text-dark"
      when "qualified", "demo_booked", "demo_completed"
        "bg-primary"
      when "won"
        "bg-success"
      else
        "bg-dark"
      end
    end

    def time_left_in_words(submission, now = Time.current)
      return "0 minutes" unless submission.editable_now?(now)

      seconds_left = (submission.editable_until - now).to_i
      minutes_left = (seconds_left / 60.0).ceil
      "#{minutes_left} minute#{'s' if minutes_left != 1}"
    end

    def submission_result_badge_class(submission)
      case submission.match_outcome
      when "attached_existing"
        "bg-info text-dark"
      when "created_new"
        "bg-success"
      else
        "bg-secondary"
      end
    end
  end
end
