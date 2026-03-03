# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passwords", type: :request do
  let!(:user) do
    User.create!(
      email_address: "user@example.com",
      password: "password",
      password_confirmation: "password",
      full_name: "User"
    )
  end

  it "renders new" do
    get new_password_path

    expect(response).to have_http_status(:ok)
  end

  it "enqueues password reset for known email" do
    expect do
      post passwords_path, params: { email_address: user.email_address }
    end.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Password reset instructions sent")
  end

  it "redirects for unknown user without sending mail" do
    expect do
      post passwords_path, params: { email_address: "missing-user@example.com" }
    end.not_to have_enqueued_mail(PasswordsMailer, :reset)

    expect(response).to redirect_to(new_session_path)
    follow_redirect!
    expect(response.body).to include("Password reset instructions sent")
  end

  it "renders edit for valid token" do
    get edit_password_path(user.password_reset_token)

    expect(response).to have_http_status(:ok)
  end

  it "redirects invalid token to new password" do
    get edit_password_path("invalid token")

    expect(response).to redirect_to(new_password_path)
    follow_redirect!
    expect(response.body).to include("Password reset link is invalid")
  end

  it "updates password with matching confirmation" do
    old_digest = user.password_digest

    put password_path(user.password_reset_token), params: { password: "new", password_confirmation: "new" }

    expect(response).to redirect_to(new_session_path)
    expect(user.reload.password_digest).not_to eq(old_digest)
    follow_redirect!
    expect(response.body).to include("Password has been reset")
  end

  it "does not update password when confirmation mismatches" do
    token = user.password_reset_token
    old_digest = user.password_digest

    put password_path(token), params: { password: "no", password_confirmation: "match" }

    expect(response).to redirect_to(edit_password_path(token))
    expect(user.reload.password_digest).to eq(old_digest)
    follow_redirect!
    expect(response.body).to include("Passwords did not match")
  end
end
