class InquiryMailer < ApplicationMailer
  default from: 'notifications@namarunu.com'
  def new_inquiry_email
    @inquiry = params[:inquiry]
    mail(to: 'namarunu@gmail.com', subject: 'New Sign up for namarunu')
  end
end
