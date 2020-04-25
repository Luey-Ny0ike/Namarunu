# Preview all emails at http://localhost:3000/rails/mailers/inquiry_mailer
class InquiryMailerPreview < ActionMailer::Preview
  def new_inquiry_email
    @inquiry = Inquiry.first
    InquiryMailer.with(inquiry: @inquiry).new_inquiry_email
  end
end
