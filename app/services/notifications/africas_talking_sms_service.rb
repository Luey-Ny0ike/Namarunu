# frozen_string_literal: true

require "AfricasTalking"

module Notifications
  class AfricasTalkingSmsService
    DEFAULT_COUNTRY_ALERT_NUMBER = "+254726160664"

    def initialize(username: nil, api_key: nil, sender_id: nil, sms_client: nil)
      @username = username || Rails.application.credentials.dig(:africastalking, :username)
      @api_key = api_key || Rails.application.credentials.dig(:africastalking, :api_key)
      @sender_id = sender_id || Rails.application.credentials.dig(:africastalking, :sender_id)
      @sms_client = sms_client
    end

    def send_message(to:, message:)
      return false if missing_credentials?

      payload = {
        "to" => to,
        "message" => message
      }
      payload["from"] = @sender_id if @sender_id.present?

      client.send(payload)
      true
    rescue StandardError => e
      Rails.logger.error("AfricasTalking SMS send failed: #{e.class} #{e.message}")
      false
    end

    private

    def client
      @sms_client ||= AfricasTalking::Initialize.new(@username, @api_key).sms
    end

    def missing_credentials?
      @username.blank? || @api_key.blank?
    end
  end
end
