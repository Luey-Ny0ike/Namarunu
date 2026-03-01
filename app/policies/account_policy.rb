# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || sales_rep? || support?
  end

  def show?
    index?
  end

  def update?
    super_admin? || sales_manager?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager? || user&.sales_rep? || user&.support?

      scope.none
    end
  end
end
