# frozen_string_literal: true

class LeadPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || sales_rep?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def update?
    return true if super_admin? || sales_manager?
    return false unless sales_rep?

    record.owned_by?(user)
  end

  def destroy?
    super_admin?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager?
      return scope.where(owner_user_id: user.id) if user&.sales_rep?

      scope.none
    end
  end
end
