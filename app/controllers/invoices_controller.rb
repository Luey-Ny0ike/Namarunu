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

  def next_invoice_number
    format("%08d", Invoice.maximum(:id).to_i + 1)
  end
end
