# frozen_string_literal: true

class Invoice::Creator
    def initialize(subscription)
      @subscription = subscription
      @store        = subscription.store
    end

    def create
      ActiveRecord::Base.transaction do
        invoice = build_invoice
        invoice.save!
        attach_line_items(invoice)
        invoice
      end
    end

    private

    def build_invoice
      Invoice.new(
        store: @store,
        name: @store.name,
        email_address: @store.email_address,
        phone_number: @store.phone_number,
        store_subscription: @subscription,
        plan_code: @subscription.plan_code,
        plan_type: @subscription.plan.plan_type,
        billing_period: @subscription.billing_period,
        currency: @subscription.currency,
        invoice_number: generate_invoice_number,
        billing_period_start: @subscription.current_period_start,
        billing_period_end: @subscription.current_period_end,
        status: "draft",
        subtotal_cents: line_item_total,
        discount_cents: 0,
        tax_cents: 0,
        total_cents: line_item_total,
        amount_paid_cents: 0,
        amount_due_cents: line_item_total
      )
    end

    def attach_line_items(invoice)
      invoice.line_items.create!(
        kind: "subscription",
        description: "#{@subscription.plan.name} plan (#{@subscription.billing_period.humanize})",
        quantity: @subscription.quantity,
        unit_amount_cents: @subscription.unit_amount_cents,
        amount_cents: line_item_total
      )
    end

    def line_item_total
      @line_item_total ||= @subscription.quantity * @subscription.unit_amount_cents
    end

    def generate_invoice_number
      last = Invoice.maximum(:id).to_i
      format("%08d", last + 1)
    end
  end
