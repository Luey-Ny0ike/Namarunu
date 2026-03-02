# frozen_string_literal: true

class Invoices::LineItemsController < ApplicationController
  before_action :set_invoice
  before_action :set_line_item, only: %i[edit update destroy]

  def new
    @line_item = @invoice.line_items.build
  end

  def create
    @line_item = @invoice.line_items.build(line_item_params)
    @line_item.amount_cents = @line_item.quantity.to_i * @line_item.unit_amount_cents.to_i

    if @line_item.save
      recalculate_totals
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("line_items", partial: "invoices/line_items", locals: { invoice: @invoice }),
            turbo_stream.replace("invoice_totals", partial: "invoices/invoice_totals", locals: { invoice: @invoice })
          ]
        end
        format.html { redirect_to invoice_path(@invoice) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @line_item.assign_attributes(line_item_params)
    @line_item.amount_cents = @line_item.quantity.to_i * @line_item.unit_amount_cents.to_i

    if @line_item.save
      recalculate_totals
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("line_items", partial: "invoices/line_items", locals: { invoice: @invoice }),
            turbo_stream.replace("invoice_totals", partial: "invoices/invoice_totals", locals: { invoice: @invoice })
          ]
        end
        format.html { redirect_to invoice_path(@invoice) }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @line_item.destroy
    recalculate_totals
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("line_items", partial: "invoices/line_items", locals: { invoice: @invoice }),
          turbo_stream.replace("invoice_totals", partial: "invoices/invoice_totals", locals: { invoice: @invoice })
        ]
      end
      format.html { redirect_to invoice_path(@invoice) }
    end
  end

  private

  def set_invoice
    @invoice = Invoice.includes(:line_items).find(params[:invoice_id])
  end

  def set_line_item
    @line_item = @invoice.line_items.find(params[:id])
  end

  def line_item_params
    params.require(:invoice_line_item).permit(:kind, :description, :quantity, :unit_amount_cents)
  end

  def recalculate_totals
    @invoice.reload
    subtotal = @invoice.line_items.sum(:amount_cents)
    @invoice.update_columns(
      subtotal_cents: subtotal,
      total_cents: subtotal,
      amount_due_cents: [subtotal - @invoice.amount_paid_cents, 0].max
    )
    @invoice.reload
  end
end
