# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadSmsNotificationJob, type: :job do
  describe "#perform" do
    it "sends an sms notification through the service" do
      inquiry = Inquiry.create!(
        full_name: "Jane Doe",
        phone_number: "+15551234567",
        business_name: "Acme Inc"
      )

      service = instance_double(Notifications::AfricasTalkingSmsService, send_message: true)
      allow(Notifications::AfricasTalkingSmsService).to receive(:new).and_return(service)
      allow(Rails.application.credentials).to receive(:dig)
        .with(:africastalking, :notify_phone)
        .and_return("+254700000001")

      described_class.perform_now(inquiry.id)

      expect(service).to have_received(:send_message).with(
        to: "+254700000001",
        message: "New lead from Acme Inc. Contact: Jane Doe (+15551234567)."
      )
    end
  end
end
