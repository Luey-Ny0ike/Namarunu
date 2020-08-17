class Inquiries::BuildController < ApplicationController
  include Wicked::Wizard

  steps :contact_information, :store_information, :billing_information, :final_step

  def show
    @inquiry = Inquiry.find(params[:inquiry_id])
    render_wizard
  end

  def update
    @inquiry = Inquiry.find(params[:inquiry_id])
    @inquiry.update_attributes(inquiry_params)
    if step == steps.last
      # InquiryMailer.with(inquiry: @inquiry).new_inquiry_email.deliver_now
      @inquiry.send_sms
    end
    render_wizard @inquiry
  end

  private
  def inquiry_params
    params.require(:inquiry).permit(:full_name, :phone_number, :email, :store_name, :domain_name, :preffered_name, :plan, :billing_type, :web_administration, :message)
  end
end
