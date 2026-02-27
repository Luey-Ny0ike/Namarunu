# frozen_string_literal: true

module InvoicesHelper
  STATUS_BADGE = {
    "draft"    => "bg-secondary",
    "issued"   => "bg-primary",
    "paid"     => "bg-success",
    "void"     => "bg-dark",
    "overdue"  => "bg-danger"
  }.freeze

  def status_badge_class(status)
    STATUS_BADGE.fetch(status, "bg-secondary")
  end

  def format_invoice_money(cents, currency)
    amount = cents / 100.0
    case currency
    when "KES" then "KES #{number_with_delimiter(amount.to_i)}"
    when "USD" then "$ #{number_with_delimiter(format('%.2f', amount))}"
    when "TZS" then "TZS #{number_with_delimiter(amount.to_i)}"
    else "#{currency} #{format('%.2f', amount)}"
    end
  end
end
