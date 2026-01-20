# frozen_string_literal: true

class InquiriesController < ApplicationController
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
    @inquiry = Inquiry.new(inquiry_params)

    unless verify_recaptcha(action: 'inquiry_submit', minimum_score: 0.5)
      respond_to do |format|
        format.html do
          flash[:alert] = 'We could not verify you are human. Please try again.'
          redirect_to build_path(:contact_information)
        end
        format.json { render json: { error: 'recaptcha_failed' }, status: :unprocessable_entity }
      end
      return
    end

    respond_to do |format|
      if @inquiry.save
        session[:inquiry_id] = @inquiry.id
        format.html { redirect_to build_path(:store_information) }
        format.json { render :show, status: :created, location: @inquiry }
      else
        format.html { redirect_to build_path(:contact_information) }
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
    params.require(:inquiry).permit(:full_name, :phone_number, :email, :store_name, :domain_name, :preffered_name,
                                    :plan, :billing_type, :web_administration, :message)
  end
end
