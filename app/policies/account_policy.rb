# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || support?
  end

  def show?
    return true if super_admin? || sales_manager?
    return false unless support?

    record.converted?
  end

  def update?
    super_admin? || sales_manager?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager?
      return scope.select(&:converted?) if user&.support?

      []
    end
  end
end
