# frozen_string_literal: true

module Admin
  class UserPolicy < ApplicationPolicy
    def index?
      super_admin?
    end

    def update?
      super_admin?
    end

    class Scope < Scope
      def resolve
        return scope.all if user&.super_admin?

        scope.none
      end
    end
  end
end
