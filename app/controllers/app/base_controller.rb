# frozen_string_literal: true

module App
  class BaseController < ApplicationController
    layout "app_layout"
    before_action :require_authentication
    before_action :require_internal_crm_access

    private

    def require_internal_crm_access
      return unless Current.user&.lead_contributor?

      redirect_to contribute_root_path, alert: "Your account has contributor access only. Please use the Contributor Portal."
    end
  end
end
