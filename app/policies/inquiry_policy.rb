# frozen_string_literal: true

class InquiryPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || sales_rep?
  end

  def show?
    super_admin? || sales_manager? || sales_rep?
  end

  def create?
    super_admin? || sales_manager? || sales_rep?
  end

  def public_create?
    true
  end

  def update?
    return true if super_admin? || sales_manager?
    return false unless sales_rep?

    record.owned_or_checked_out_by?(user)
  end

  def destroy?
    super_admin?
  end

  def reassign_checkout?
    super_admin? || sales_manager?
  end

  def won_deals?
    super_admin? || sales_manager?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager? || user&.sales_rep?

      scope.none
    end
  end
end
