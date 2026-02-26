# frozen_string_literal: true

class Inquiry < ApplicationRecord
  # Validations
  validates_presence_of :full_name, :phone_number

  require "AfricasTalking"
  def send_sms
    username = Rails.application.credentials.dig(:africastalking, :username)
    apikey = Rails.application.credentials.dig(:africastalking, :api_key)
    at = AfricasTalking::Initialize.new(username, apikey)
    sms = at.sms
    to = "+254726160664"
    @message = "New signup on namarunu.com, check your email"
    # from = "NAMARUNU"
    options = {
      "to" => to,
      "message" => @message.html_safe
      # "from" => from
    }
    begin
      # Thats it, hit send and we'll take care of the rest.
      reports = sms.send options
      reports.each do |report|
        puts report.to_yaml
      end
    rescue AfricasTalking::AfricasTalkingException => e
      puts "Encountered an error: #{e.message}"
    end
  end
end
