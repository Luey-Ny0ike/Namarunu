# frozen_string_literal: true

class InvoicesController < ApplicationController
  def show
    @invoice = Invoice.includes(:store, :line_items).find(params[:id])

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
end
