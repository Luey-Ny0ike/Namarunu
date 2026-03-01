# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portal access", type: :request do
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

  it "redirects lead_contributor away from app namespace" do
    contributor = build_user(:lead_contributor)
    sign_in_as(contributor)

    get app_root_path

    expect(response).to redirect_to(contribute_root_path)
    follow_redirect!
    expect(response.body).to include("contributor access only")
    expect(response.body).to include("Contributor Portal")
  end

  it "allows lead_contributor into contributor portal" do
    contributor = build_user(:lead_contributor)
    sign_in_as(contributor)

    get contribute_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Contributor Portal")
  end

  it "blocks sales reps from contributor portal" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get contribute_root_path

    expect(response).to redirect_to(app_root_path)
  end

  it "allows super_admin into contributor portal" do
    super_admin = build_user(:super_admin)
    sign_in_as(super_admin)

    get contribute_root_path

    expect(response).to have_http_status(:ok)
  end

  it "allows sales_manager into contributor portal" do
    manager = build_user(:sales_manager)
    sign_in_as(manager)

    get contribute_root_path

    expect(response).to have_http_status(:ok)
  end
end
