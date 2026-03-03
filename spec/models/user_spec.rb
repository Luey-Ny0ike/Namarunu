# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "downcases and strips email_address" do
    user = described_class.new(email_address: " DOWNCASED@EXAMPLE.COM ")

    expect(user.email_address).to eq("downcased@example.com")
  end

  it "defaults new users to sales_rep role" do
    user = described_class.create!(
      email_address: "rep@example.com",
      password: "password123",
      password_confirmation: "password123",
      full_name: "Sales Rep"
    )

    expect(user.role).to eq("sales_rep")
    expect(user).to be_sales_rep
  end

  it "supports all expected role values" do
    expect(described_class.roles.keys).to contain_exactly(
      "super_admin",
      "sales_manager",
      "sales_rep",
      "support",
      "finance",
      "lead_contributor"
    )
  end
end
