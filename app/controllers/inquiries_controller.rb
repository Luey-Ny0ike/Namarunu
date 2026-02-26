# frozen_string_literal: true

class InquiriesController < ApplicationController
  allow_unauthenticated_access only: %i[create]
  before_action :set_inquiry, only: %i[show edit update destroy reassign_checkout]

  # GET /inquiries
  # GET /inquiries.json
  def index
    authorize Inquiry
    @inquiries = set_page_and_extract_portion_from(policy_scope(Inquiry).order(created_at: :desc))
  end

  # GET /inquiries/1
  # GET /inquiries/1.json
  def show
    authorize @inquiry
  end

  # GET /inquiries/new
  def new
    authorize Inquiry
    @inquiry = Inquiry.new
  end

  # GET /inquiries/1/edit
  def edit
    authorize @inquiry
  end

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
          format.html { redirect_to @inquiry, notice: "Lead created successfully." }
        else
          session[:inquiry_id] = @inquiry.id
          InquiryMailer.with(inquiry: @inquiry).new_inquiry_email.deliver_later
          LeadSmsNotificationJob.perform_later(@inquiry.id)
          format.html { redirect_to build_path(:business_context) }
        end
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
    authorize @inquiry
    respond_to do |format|
      if @inquiry.update(inquiry_params)
        format.html { redirect_to @inquiry, notice: "Inquiry was successfully updated." }
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
    authorize @inquiry
    @inquiry.destroy
    respond_to do |format|
      format.html { redirect_to inquiries_url, notice: "Inquiry was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def won_deals
    authorize Inquiry, :won_deals?
    @inquiries = set_page_and_extract_portion_from(Inquiry.where(status: "won").order(created_at: :desc))
    render :index
  end

  def reassign_checkout
    authorize @inquiry, :reassign_checkout?
    @inquiry.update!(checked_out_by: User.find(params.expect(:checked_out_by_id)))
    redirect_to @inquiry, notice: "Lead checkout reassigned."
  rescue ActiveRecord::RecordNotFound
    redirect_to @inquiry, alert: "User not found."
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
