# frozen_string_literal: true

class InquiriesController < ApplicationController
  allow_unauthenticated_access only: %i[create]

  # POST /inquiries
  # POST /inquiries.json
  def create
    @inquiry = Inquiry.new(contact_params.merge(tracking_params))
    @inquiry.owner ||= Current.user if authenticated?
    @inquiry.source ||= "marketing_get_started"
    @inquiry.status ||= "new"
    authorize(@inquiry, authenticated? ? :create? : :public_create?)

    if @inquiry.website.present? # honepot field
      redirect_to build_path(:get_started), alert: "Unable to submit. Please try again."
      return
    end

    respond_to do |format|
      if @inquiry.save
        if authenticated?
          format.html { redirect_to app_inquiry_path(@inquiry), notice: "Lead created successfully." }
        else
          session[:inquiry_id] = @inquiry.id
          InquiryMailer.with(inquiry: @inquiry).new_inquiry_email.deliver_later
          LeadSmsNotificationJob.perform_later(@inquiry.id)
          format.html { redirect_to build_path(:business_context) }
        end
        format.json { render json: { id: @inquiry.id, lead_id: @inquiry.lead_id }, status: :created, location: app_inquiry_path(@inquiry) }
      else
        format.html do
          flash.now[:alert] = "Please review the highlighted fields."
          render "inquiries/build/get_started", status: :unprocessable_entity
        end
        format.json { render json: @inquiry.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def inquiry_params
    params.require(:inquiry).permit(:full_name, :phone_number, :email, :business_name, :business_type, :sell_in_store,
                                    :business_link, :intent, :source, :status, :utm_source, :utm_medium, :utm_campaign,
                                    :utm_term, :utm_content, :website, :store_name, :domain_name, :preffered_name,
                                    :plan, :billing_type, :web_administration, :message)
  end

  def contact_params
    inquiry_params.slice(:full_name, :phone_number, :email, :business_name).merge(website: inquiry_params[:website])
  end

  def tracking_params
    params.permit(:utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content)
  end
end
