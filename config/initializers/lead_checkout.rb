# frozen_string_literal: true

Rails.application.configure do
  config.x.leads ||= ActiveSupport::OrderedOptions.new
  config.x.leads.checkout_duration = ENV.fetch("LEAD_CHECKOUT_DURATION_MINUTES", 120).to_i.minutes
end
