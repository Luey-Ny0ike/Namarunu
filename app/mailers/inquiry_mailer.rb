# frozen_string_literal: true

class InquiryMailer < ApplicationMailer
  default from: 'info@namarunu.com'

  def new_inquiry_email
    @inquiry = params[:inquiry]
    @admin_link = inquiry_url(@inquiry)

    mail(to: 'namarunu@gmail.com', subject: "New marketing lead: #{@inquiry.business_name}")
  end
end
