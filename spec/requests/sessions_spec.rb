# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) do
    User.create!(
      email_address: "user@example.com",
      password: "password",
      password_confirmation: "password",
      full_name: "User"
    )
  end

  it "renders new" do
    get new_session_path

    expect(response).to have_http_status(:ok)
  end

  it "creates a session with valid credentials" do
    post session_path, params: { email_address: user.email_address, password: "password" }

    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_present
  end

  it "rejects invalid credentials" do
    post session_path, params: { email_address: user.email_address, password: "wrong" }

    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_nil
  end

  it "destroys the session" do
    post session_path, params: { email_address: user.email_address, password: "password" }

    delete session_path

    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_blank
  end
end
