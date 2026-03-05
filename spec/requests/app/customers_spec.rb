# frozen_string_literal: true

require "rails_helper"

RSpec.describe "App::Customers", type: :request do
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

  it "shows only owned customers in index and supports status/search filters" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    own_pending = Account.create!(name: "Own Pending", owner_user: rep, status: :pending)
    Account.create!(name: "Own Active", owner_user: rep, status: :active)
    Account.create!(name: "Other Pending", owner_user: other_rep, status: :pending)
    Account.create!(name: "Own Cancelled", owner_user: rep, status: :cancelled)

    get app_customers_path
    expect(response.body).to include("Own Pending")
    expect(response.body).not_to include("Own Active")
    expect(response.body).not_to include("Other Pending")
    expect(response.body).not_to include("Own Cancelled")

    get app_customers_path(status: "active")
    expect(response.body).to include("Own Active")
    expect(response.body).not_to include("Own Pending")

    get app_customers_path(status: "cancelled", q: "own")
    expect(response.body).to include("Own Cancelled")
    expect(response.body).not_to include("Own Pending")

    get app_customer_path(own_pending)
    expect(response).to have_http_status(:ok)
  end

  it "allows managing contacts only on owned customers" do
    rep = build_user(:sales_rep)
    other_rep = build_user(:sales_rep)
    sign_in_as(rep)

    own_customer = Account.create!(name: "Owned", owner_user: rep, status: :pending)
    other_customer = Account.create!(name: "Other", owner_user: other_rep, status: :pending)

    post app_customer_contacts_path(own_customer), params: {
      contact: { name: "Primary", phone: "+15551234567", email: "primary@example.com", role: "Owner" }
    }

    expect(response).to redirect_to(app_customer_path(own_customer))
    contact = own_customer.contacts.order(:id).last
    expect(contact.name).to eq("Primary")

    patch app_customer_contact_path(own_customer, contact), params: {
      contact: { role: "Decision Maker" }
    }
    expect(response).to redirect_to(app_customer_path(own_customer))
    expect(contact.reload.role).to eq("Decision Maker")

    delete app_customer_contact_path(own_customer, contact)
    expect(response).to redirect_to(app_customer_path(own_customer))
    expect { contact.reload }.to raise_error(ActiveRecord::RecordNotFound)

    post app_customer_contacts_path(other_customer), params: {
      contact: { name: "Blocked", phone: "+15550000000" }
    }
    expect(response).to have_http_status(:not_found)
  end

  it "allows manager to create customer with owner and initial contacts" do
    manager = build_user(:sales_manager)
    rep = build_user(:sales_rep)
    sign_in_as(manager)

    get new_app_customer_path
    expect(response).to have_http_status(:ok)

    expect do
      post app_customers_path, params: {
        account: {
          name: "Manager Created Customer",
          industry: "fashion",
          location: "Nairobi",
          status: "active",
          owner_user_id: rep.id,
          contacts_attributes: {
            "0" => { name: "", phone: "+254700111222", email: "", role: "Owner" }
          }
        }
      }
    end.to change(Account, :count).by(1).and change(Contact, :count).by(1)

    created = Account.order(:id).last
    expect(response).to redirect_to(app_customer_path(created))
    expect(created.owner_user_id).to eq(rep.id)
    expect(created.status).to eq("active")
    expect(created.contacts.first.phone).to eq("+254700111222")
  end

  it "prevents sales rep from manually creating customers" do
    rep = build_user(:sales_rep)
    sign_in_as(rep)

    get new_app_customer_path
    expect(response).to redirect_to(root_path)

    post app_customers_path, params: {
      account: { name: "Blocked Rep Customer", industry: "fashion" }
    }
    expect(response).to redirect_to(root_path)
  end
end
