# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invoices", type: :request do
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

  it "writes create_invoice activity when creating an invoice from a lead" do
    user = build_user(:sales_rep)
    sign_in_as(user)

    lead = Lead.create!(
      business_name: "Invoice Activity Lead",
      owner_user: user,
      lead_contacts_attributes: [{ name: "Lead Contact", phone: "+15551230001" }]
    )

    expect do
      post invoices_path, params: {
        lead_id: lead.id,
        save_as: "draft",
        invoice: {
          name: lead.business_name,
          email_address: "billing@example.com",
          phone_number: "+15551239999",
          plan_code: "sungura",
          plan_type: "starter",
          billing_period: "monthly",
          billing_period_start: Date.current,
          billing_period_end: Date.current + 30.days,
          currency: "KES",
          status: "draft",
          due_at: Date.current + 14.days,
          notes: "Test invoice",
          line_items_attributes: {
            "0" => {
              kind: "subscription",
              description: "Starter plan",
              quantity: 1,
              unit_amount_cents: 10_000,
              amount_cents: 10_000
            }
          }
        }
      }
    end.to change(Invoice, :count).by(1)
      .and change { Activity.where(action_type: "create_invoice").count }.by(1)

    invoice = Invoice.order(:created_at).last
    activity = Activity.where(subject: lead, action_type: "create_invoice").order(:created_at).last

    expect(response).to redirect_to(invoice_path(invoice))
    expect(activity).to be_present
    expect(activity.actor_user).to eq(user)
    expect(activity.metadata).to include(
      "lead_id" => lead.id,
      "invoice_id" => invoice.id,
      "invoice_number" => invoice.invoice_number,
      "invoice_status" => invoice.status
    )
  end
end
