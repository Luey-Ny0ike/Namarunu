# frozen_string_literal: true

module Contribute
  class BaseController < ApplicationController
    layout "contribute_layout"
    before_action :require_authentication
    before_action :require_contributor_portal_access

    private

    def require_contributor_portal_access
      return if Current.user&.super_admin? || Current.user&.sales_manager? || Current.user&.lead_contributor?

      redirect_to app_root_path, alert: "You are not authorized to access the Contributor Portal."
    end
  end
end
