# frozen_string_literal: true

class InquiriesController < ApplicationController
  allow_unauthenticated_access except: %i[ index show ]
  before_action :set_inquiry, only: %i[show edit update destroy]

  # GET /inquiries
  # GET /inquiries.json
  def index
    @inquiries = set_page_and_extract_portion_from Inquiry.order(created_at: :desc)
  end

  # GET /inquiries/1
  # GET /inquiries/1.json
  def show; end

  # GET /inquiries/new
  def new
    @inquiry = Inquiry.new
  end

  # GET /inquiries/1/edit
  def edit; end

  # POST /inquiries
  # POST /inquiries.json
  def create
    @inquiry = Inquiry.new(contact_params.merge(tracking_params))
    @inquiry.source ||= "marketing_get_started"
    @inquiry.status ||= "new"

    if @inquiry.website.present? # honepot field
      redirect_to build_path(:get_started), alert: "Unable to submit. Please try again."
      return
    end

    respond_to do |format|
      if @inquiry.save
        session[:inquiry_id] = @inquiry.id
        InquiryMailer.with(inquiry: @inquiry).new_inquiry_email.deliver_later
        LeadSmsNotificationJob.perform_later(@inquiry.id)
        format.html { redirect_to build_path(:business_context) }
        format.json { render :show, status: :created, location: @inquiry }
      else
        format.html do
          flash.now[:alert] = "Please review the highlighted fields."
          render "inquiries/build/get_started", status: :unprocessable_entity
        end
        format.json { render json: @inquiry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /inquiries/1
  # PATCH/PUT /inquiries/1.json
  def update
    respond_to do |format|
      if @inquiry.update(inquiry_params)
        format.html { redirect_to @inquiry, notice: 'Inquiry was successfully updated.' }
        format.json { render :show, status: :ok, location: @inquiry }
      else
        format.html { render :edit }
        format.json { render json: @inquiry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /inquiries/1
  # DELETE /inquiries/1.json
  def destroy
    @inquiry.destroy
    respond_to do |format|
      format.html { redirect_to inquiries_url, notice: 'Inquiry was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_inquiry
    @inquiry = Inquiry.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
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
