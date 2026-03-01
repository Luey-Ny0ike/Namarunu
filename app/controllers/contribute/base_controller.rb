# frozen_string_literal: true

module Contribute
  class BaseController < ApplicationController
    layout "contribute_layout"
    before_action :require_authentication
  end
end
