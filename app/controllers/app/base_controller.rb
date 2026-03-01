# frozen_string_literal: true

module App
  class BaseController < ApplicationController
    layout "app_layout"
    before_action :require_authentication
  end
end
