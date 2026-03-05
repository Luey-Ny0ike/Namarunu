# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::Inquiries", type: :request do
  def build_user(role)
    User.create!(
      email_address: "#{role}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: role.to_s.humanize,
      role: role
    )
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
    expect(response).to have_http_status(:redirect)
  end

  it "allows manager access to app inquiries index" do
    manager = build_user(:sales_manager)
    sign_in_as(manager)

    Inquiry.create!(full_name: "Jane", phone_number: "+15551230000", business_name: "Acme Inc")

    get app_inquiries_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Inquiries")
    expect(response.body).to include("Submitted")
  end

  it "shows Open Lead action when inquiry is linked" do
    manager = build_user(:sales_manager)
    sign_in_as(manager)

    inquiry = Inquiry.create!(full_name: "Jane", phone_number: "+15551230000", business_name: "Acme Inc")

    get app_inquiry_path(inquiry)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Linked lead")
    expect(response.body).to include(app_lead_path(inquiry.reload.lead_id))
    expect(response.body).to include("Open Lead")
    expect(response.body).to include("Submitted")
  end

  it "converts an unlinked inquiry manually" do
    manager = build_user(:sales_manager)
    sign_in_as(manager)

    inquiry = Inquiry.create!(full_name: "Jane", phone_number: "+15551230000", business_name: "Acme Inc")
    inquiry.update_column(:lead_id, nil)

    post convert_to_lead_app_inquiry_path(inquiry)

    expect(response).to redirect_to(app_inquiry_path(inquiry))
    expect(inquiry.reload.lead_id).to be_present
  end

  it "blocks sales reps from app inquiries index" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get app_inquiries_path

    expect(response).to redirect_to(root_path)
  end
end
