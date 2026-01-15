# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_inquiry

  def set_inquiry
    @inquiry = Inquiry.new
  end
end
