class Inquiry < ApplicationRecord
  require 'AfricasTalking'
  def send_sms
    username = Rails.application.credentials.dig(:africastalking, :username)
    apikey = Rails.application.credentials.dig(:africastalking, :api_key)
    at = AfricasTalking::Initialize.new(username, apikey)
    sms = at.sms
    to = "+254726160664, +254715553341"
    @message = "New signup on namarunu.com, check your email"
    # from = "NAMARUNU"
    options = {
        "to" => to,
        "message" => @message.html_safe,
        # "from" => from
    }
    begin
        # Thats it, hit send and we'll take care of the rest.
        reports = sms.send options
    reports.each {|report|
        puts report.to_yaml
    }
    rescue AfricasTalking::AfricasTalkingException => ex
    puts 'Encountered an error: ' + ex.message
    end
  end
end
