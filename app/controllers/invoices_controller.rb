# frozen_string_literal: true

class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show edit update destroy]

  def index
    @invoices = Invoice.includes(:store).order(created_at: :desc)
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        pdf = Invoice::PdfGenerator.new(@invoice).render
        send_data pdf,
                  filename: "invoice-#{@invoice.invoice_number}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  def new
    @invoice = Invoice.new(status: "draft", currency: "KES")
    if params[:lead_id].present?
      @lead = Lead.includes(:lead_contacts).find(params[:lead_id])
      contact = @lead.lead_contacts.order(:created_at, :id).first
      @invoice.name          = @lead.business_name
      @invoice.email_address = contact&.email
      @invoice.phone_number  = contact&.phone
    end
    @invoice.line_items.build
    @next_invoice_number = next_invoice_number
    @plans = Plan.all
  end

  def create
    @invoice = Invoice.new(invoice_params.except(:store_id))
    @invoice.store = resolve_store
    @invoice.invoice_number = next_invoice_number
    apply_status_from_button
    apply_default_money_fields

    if @invoice.save
      recalculate_totals(@invoice)
      write_create_invoice_activity!(@invoice)
      redirect_to invoice_path(@invoice)
    else
      @next_invoice_number = @invoice.invoice_number || next_invoice_number
      @plans = Plan.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @next_invoice_number = @invoice.invoice_number
    @plans = Plan.all
  end

  def update
    apply_status_from_button
    @invoice.assign_attributes(invoice_params.except(:store_id))
    @invoice.store = resolve_store
    if @invoice.save
      recalculate_totals(@invoice)
      redirect_to invoice_path(@invoice)
    else
      @next_invoice_number = @invoice.invoice_number
      @plans = Plan.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to invoices_path
  end

  private

  def set_invoice
    @invoice = Invoice.includes(:store, :line_items).find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :store_id, :name, :email_address, :phone_number,
      :plan_code, :plan_type, :billing_period, :currency,
      :billing_period_start, :billing_period_end, :status, :issued_at,
      :due_at, :notes, :subtotal_cents, :discount_cents, :tax_cents,
      :total_cents, :amount_paid_cents, :amount_due_cents,
      line_items_attributes: %i[id _destroy kind description quantity unit_amount_cents amount_cents]
    )
  end

  def resolve_store
    store_id = params.dig(:invoice, :store_id).presence
    store_id ? Store.find(store_id) : nil
  end

  def apply_status_from_button
    case params[:save_as]
    when "issued"
      @invoice.status = "issued"
      @invoice.issued_at ||= Date.current
    when "draft"
      @invoice.status = "draft"
    end
  end

  def apply_default_money_fields
    @invoice.subtotal_cents    ||= 0
    @invoice.discount_cents    ||= 0
    @invoice.tax_cents         ||= 0
    @invoice.total_cents       ||= 0
    @invoice.amount_paid_cents ||= 0
    @invoice.amount_due_cents  ||= 0
  end

  def recalculate_totals(invoice)
    invoice.sync_totals_and_payment_status!
  end

  def write_create_invoice_activity!(invoice)
    return unless Current.user.present?

    lead = resolve_lead_for_activity
    subject = lead || invoice

    Activity.create!(
      actor_user: Current.user,
      subject: subject,
      action_type: "create_invoice",
      metadata: {
        lead_id: lead&.id,
        invoice_id: invoice.id,
        invoice_number: invoice.invoice_number,
        invoice_status: invoice.status
      }.compact,
      occurred_at: Time.current
    )
  end

  def resolve_lead_for_activity
    lead_id = params[:lead_id].presence
    return if lead_id.blank?

    Lead.find_by(id: lead_id)
  end

  def next_invoice_number
    format("%08d", Invoice.maximum(:id).to_i + 1)
  end
end
