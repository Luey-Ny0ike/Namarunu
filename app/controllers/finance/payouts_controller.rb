# frozen_string_literal: true

module Finance
  class PayoutsController < ApplicationController
    def index
      authorize([:finance, :payout], :index?)
    end
  end
end
