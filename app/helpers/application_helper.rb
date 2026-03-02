# frozen_string_literal: true

module ApplicationHelper
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
