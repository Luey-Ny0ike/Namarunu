# frozen_string_literal: true

class InvoiceArchivesController < ApplicationController
  require "zip"

  def show
    invoices = Invoice.includes(:line_items).order(created_at: :desc)

    zip_data = Zip::OutputStream.write_buffer do |zip|
      invoices.each do |invoice|
        pdf = Invoice::PdfGenerator.new(invoice).render
        zip.put_next_entry("invoice-#{invoice.invoice_number}.pdf")
        zip.write(pdf)
      end
    end

    zip_data.rewind
    send_data zip_data.read,
              filename: "invoices-#{Date.current.iso8601}.zip",
              type: "application/zip",
              disposition: "attachment"
  end
end
