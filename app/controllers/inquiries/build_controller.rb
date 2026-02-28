# frozen_string_literal: true

module Inquiries
  class BuildController < ApplicationController
    include Wicked::Wizard
    allow_unauthenticated_access
    steps :get_started, :business_context, :thanks

    def show
      case step
      when :get_started
        @inquiry = Inquiry.new
        session[:inquiry_id] = nil
      when :business_context
        @inquiry = inquiry_from_session
      when :thanks
        @inquiry = inquiry_from_session
        session.delete(:inquiry_id)
      else
        @inquiry = inquiry_from_session
      end
      render_wizard
    rescue ActiveRecord::RecordNotFound
      redirect_to build_path(:get_started), alert: "Please start your inquiry again."
    end

    def update
      @inquiry = inquiry_from_session
      @inquiry.require_business_context = true

      if @inquiry.update(business_context_params)
        render_wizard @inquiry
      else
        render step, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to build_path(:get_started), alert: "Please start your inquiry again."
    end

    private

    def inquiry_from_session
      inquiry_id = session[:inquiry_id]
      raise ActiveRecord::RecordNotFound if inquiry_id.blank?

      Inquiry.find(inquiry_id)
    end

    def business_context_params
      params.require(:inquiry).permit(:business_type, :sell_in_store, :business_link, :intent)
    end
  end
end
