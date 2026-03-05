# frozen_string_literal: true

module App
  class InquiriesController < BaseController
    before_action :set_inquiry, only: %i[show edit update destroy convert_to_lead]

    def index
      authorize Inquiry
      @inquiries = set_page_and_extract_portion_from(policy_scope(Inquiry).includes(:lead).order(created_at: :desc))
    end

    def show
      authorize @inquiry
    end

    def new
      authorize Inquiry
      @inquiry = Inquiry.new
    end

    def edit
      authorize @inquiry
    end

    def create
      authorize Inquiry
      @inquiry = Inquiry.new(inquiry_params)

      respond_to do |format|
        if @inquiry.save
          format.html { redirect_to app_inquiry_path(@inquiry), notice: "Inquiry was successfully created." }
          format.json { render :show, status: :created, location: app_inquiry_path(@inquiry) }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @inquiry.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      authorize @inquiry

      respond_to do |format|
        if @inquiry.update(inquiry_params)
          format.html { redirect_to app_inquiry_path(@inquiry), notice: "Inquiry was successfully updated." }
          format.json { render :show, status: :ok, location: app_inquiry_path(@inquiry) }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @inquiry.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      authorize @inquiry
      @inquiry.destroy

      respond_to do |format|
        format.html { redirect_to app_inquiries_url, notice: "Inquiry was successfully destroyed." }
        format.json { head :no_content }
      end
    end

    def won_deals
      authorize Inquiry, :won_deals?
      @inquiries = set_page_and_extract_portion_from(policy_scope(Inquiry).includes(:lead).where(status: "won").order(created_at: :desc))
      render :index
    end

    def convert_to_lead
      authorize @inquiry, :update?
      InquiryToLeadService.new(@inquiry).call
      redirect_to app_inquiry_path(@inquiry), notice: "Inquiry converted and linked to CRM lead."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to app_inquiry_path(@inquiry), alert: "Conversion failed: #{error.record.errors.full_messages.to_sentence}"
    end

    private

    def set_inquiry
      @inquiry = Inquiry.find(params[:id])
    end

    def inquiry_params
      params.require(:inquiry).permit(:full_name, :phone_number, :email, :business_name, :business_type, :sell_in_store,
                                      :business_link, :intent, :source, :status, :utm_source, :utm_medium, :utm_campaign,
                                      :utm_term, :utm_content, :website, :store_name, :domain_name, :preffered_name,
                                      :plan, :billing_type, :web_administration, :message)
    end
  end
end
