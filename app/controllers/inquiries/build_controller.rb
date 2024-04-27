class Inquiries::BuildController < ApplicationController
  include Wicked::Wizard

  steps :contact_information, :store_information, :billing_information, :final_step

  def show
    case step
    when :contact_information
      @inquiry = Inquiry.new
      session[:inquiry_id] = nil
    when :billing_information
      skip_step
    else
      @inquiry = Inquiry.find(session[:inquiry_id])
    end
    render_wizard
  end

  def update
    @inquiry = Inquiry.find(session[:inquiry_id])
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
