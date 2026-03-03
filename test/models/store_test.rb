# frozen_string_literal: true

require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "valid store saves" do
    store = Store.new(name: "Test Store", currency: "KES")
    assert store.valid?
  end

  test "requires name" do
    store = Store.new(currency: "KES")
    assert_not store.valid?
    assert_includes store.errors[:name], "can't be blank"
  end

  test "requires currency" do
    store = Store.new(name: "Test Store", currency: nil)
    assert_not store.valid?
    assert_includes store.errors[:currency], "can't be blank"
  end

  test "currency must be KES, USD, or TZS" do
    store = Store.new(name: "Test Store", currency: "GBP")
    assert_not store.valid?
    assert store.errors[:currency].any?
  end

  test "accepts all valid currencies" do
    %w[KES USD TZS].each do |currency|
      store = Store.new(name: "Test Store", currency: currency)
      assert store.valid?, "expected #{currency} to be valid"
    end
  end

  test "rejects malformed email" do
    store = Store.new(name: "Test Store", currency: "KES", email_address: "not-an-email")
    assert_not store.valid?
    assert store.errors[:email_address].any?
  end

  test "allows blank email" do
    store = Store.new(name: "Test Store", currency: "KES", email_address: "")
    assert store.valid?
  end

  test "accepts valid email" do
    store = Store.new(name: "Test Store", currency: "KES", email_address: "hello@example.com")
    assert store.valid?
  end

  test "has many subscriptions" do
    store = stores(:glow_organics)
    assert_respond_to store, :subscriptions
  end

  test "has many invoices" do
    store = stores(:glow_organics)
    assert_respond_to store, :invoices
  end
end
