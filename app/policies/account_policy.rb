# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || sales_rep?
  end

  def show?
    return true if super_admin? || sales_manager?

    sales_rep? && owned_account?
  end

  def update?
    return true if super_admin? || sales_manager?

    sales_rep? && owned_account?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager?
      return scope.where(owner_user_id: user.id) if user&.sales_rep?

      scope.none
    end
  end

  private

  def owned_account?
    record.owner_user_id == user&.id
  end
end
