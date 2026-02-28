# frozen_string_literal: true

module Finance
  class PayoutPolicy < ApplicationPolicy
    def index?
      super_admin? || finance?
    end

    def show?
      index?
    end
  end
end
