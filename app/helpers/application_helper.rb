# frozen_string_literal: true

module ApplicationHelper
  def lead_status_badge_class(status)
    case status.to_s
    when "new", "in_progress"
      "text-bg-secondary"
    when "contacted", "qualified"
      "text-bg-info"
    when "demo_booked", "demo_completed"
      "text-bg-primary"
    when "awaiting_commitment", "invoice_sent"
      "text-bg-warning text-dark"
    when "won"
      "text-bg-success"
    when "lost"
      "text-bg-danger"
    when "unresponsive"
      "text-bg-dark"
    else
      "text-bg-secondary"
    end
  end

  def lead_temperature_badge_class(temperature)
    case temperature.to_s
    when "hot"
      "text-bg-danger"
    when "warm"
      "text-bg-warning text-dark"
    when "cold"
      "text-bg-secondary"
    else
      "text-bg-secondary"
    end
  end

  def account_status_badge_class(status)
    case status.to_s
    when "pending"
      "text-bg-warning text-dark"
    when "active"
      "text-bg-success"
    when "cancelled"
      "text-bg-secondary"
    else
      "text-bg-secondary"
    end
  end

  def nav_link_to(name, path, match: :exact, **options)
    active = nav_link_active?(path, match)

    classes = Array(options.delete(:class))
    classes.concat(%w[nav-link link-light])
    if active
      classes.concat(%w[active fw-semibold text-white text-decoration-underline])
    else
      classes << "text-white-50"
    end

    options[:"aria-current"] = "page" if active

    link_to(name, path, **options.merge(class: classes.uniq.join(" ")))
  end

  private

  def nav_link_active?(path, match)
    case match
    when :prefix
      target = path.is_a?(String) ? path : url_for(path)
      request.path == target || request.path.start_with?("#{target}/")
    when Regexp
      request.path.match?(match)
    else
      current_page?(path)
    end
  end
end
