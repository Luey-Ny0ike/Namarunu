# frozen_string_literal: true

class LeadSmsNotificationJob < ApplicationJob
  queue_as :default

  def perform(inquiry_id)
    inquiry = Inquiry.find_by(id: inquiry_id)
    return if inquiry.blank?

    recipient = Rails.application.credentials.dig(:africastalking, :notify_phone) ||
                Notifications::AfricasTalkingSmsService::DEFAULT_COUNTRY_ALERT_NUMBER

    message = "New lead from #{inquiry.business_name}. Contact: #{inquiry.full_name} (#{inquiry.phone_number})."

    Notifications::AfricasTalkingSmsService.new.send_message(to: recipient, message: message)
  end
end
