# frozen_string_literal: true

require "rails_helper"

RSpec.describe Store, type: :model do
  it "validates a store with required fields" do
    store = described_class.new(name: "Test Store", currency: "KES")

    expect(store).to be_valid
  end

  it "requires name" do
    store = described_class.new(currency: "KES")

    expect(store).not_to be_valid
    expect(store.errors[:name]).to include("can't be blank")
  end

  it "requires currency" do
    store = described_class.new(name: "Test Store", currency: nil)

    expect(store).not_to be_valid
    expect(store.errors[:currency]).to include("can't be blank")
  end

  it "rejects unsupported currency" do
    store = described_class.new(name: "Test Store", currency: "GBP")

    expect(store).not_to be_valid
    expect(store.errors[:currency]).to be_present
  end

  it "accepts all valid currencies" do
    %w[KES USD TZS].each do |currency|
      store = described_class.new(name: "Test Store", currency: currency)
      expect(store).to be_valid
    end
  end

  it "rejects malformed email" do
    store = described_class.new(name: "Test Store", currency: "KES", email_address: "not-an-email")

    expect(store).not_to be_valid
    expect(store.errors[:email_address]).to be_present
  end

  it "allows blank email" do
    store = described_class.new(name: "Test Store", currency: "KES", email_address: "")

    expect(store).to be_valid
  end

  it "accepts valid email" do
    store = described_class.new(name: "Test Store", currency: "KES", email_address: "hello@example.com")

    expect(store).to be_valid
  end

  it "has many subscriptions" do
    association = described_class.reflect_on_association(:subscriptions)

    expect(association.macro).to eq(:has_many)
  end

  it "has many invoices" do
    association = described_class.reflect_on_association(:invoices)

    expect(association.macro).to eq(:has_many)
  end
end
