# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Build inquiry flow", type: :request do
  include ActiveJob::TestHelper

  before do
    clear_enqueued_jobs
  end

  describe "POST /inquiries (step 1)" do
    it "creates an inquiry and enqueues email + sms notifications" do
      params = {
        inquiry: {
          full_name: "  Jane Doe  ",
          phone_number: " +1 555 123 4567 ",
          business_name: "  Acme Inc  ",
          email: " jane@example.com ",
          website: ""
        },
        utm_source: "google",
        utm_medium: "cpc"
      }

      expect do
        post inquiries_path, params: params
      end.to change(Inquiry, :count).by(1)
        .and have_enqueued_mail(InquiryMailer, :new_inquiry_email)
        .and have_enqueued_job(LeadSmsNotificationJob)

      expect(response).to redirect_to(build_path(:business_context))

      inquiry = Inquiry.last
      expect(inquiry.full_name).to eq("Jane Doe")
      expect(inquiry.business_name).to eq("Acme Inc")
      expect(inquiry.utm_source).to eq("google")
      expect(inquiry.utm_medium).to eq("cpc")
      expect(inquiry.source).to eq("marketing_get_started")
      expect(inquiry.status).to eq("new")
    end
  end

  describe "PATCH /build/business_context (step 2)" do
    it "updates the existing inquiry and redirects to thanks" do
      post inquiries_path, params: {
        inquiry: {
          full_name: "Jane Doe",
          phone_number: "+15551234567",
          business_name: "Acme Inc",
          website: ""
        }
      }

      inquiry = Inquiry.last

      patch build_path(:business_context), params: {
        inquiry: {
          business_type: "Fashion",
          sell_in_store: true,
          business_link: "https://example.com",
          intent: "need_both"
        }
      }

      expect(response).to redirect_to(build_path(:thanks))

      inquiry.reload
      expect(inquiry.business_type).to eq("Fashion")
      expect(inquiry.sell_in_store).to be(true)
      expect(inquiry.business_link).to eq("https://example.com")
      expect(inquiry.intent).to eq("need_both")
    end
  end

  describe "GET /build/thanks (step 3)" do
    it "renders the WhatsApp CTA" do
      post inquiries_path, params: {
        inquiry: {
          full_name: "Jane Doe",
          phone_number: "+15551234567",
          business_name: "Acme Inc",
          website: ""
        }
      }

      get build_path(:thanks)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("reach out ASAP")
      expect(response.body).to include("+254726160664")
      expect(response.body).to include("api.whatsapp.com/send")
      expect(response.body).to include("Business%3A+Acme+Inc")
      expect(response.body).to include("Phone%3A+%2B15551234567")
    end
  end
end
