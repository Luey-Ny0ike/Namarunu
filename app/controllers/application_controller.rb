# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  before_action :set_inquiry
  rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized

  def set_inquiry
    @inquiry = Inquiry.new
  end

  private

  def pundit_user
    Current.user
  end

  def handle_not_authorized
    redirect_to(root_path, alert: "You are not authorized to perform this action.")
  end
end
