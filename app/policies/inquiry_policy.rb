# frozen_string_literal: true

class InquiryPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def public_create?
    true
  end

  def update?
    index?
  end

  def destroy?
    super_admin?
  end

  def won_deals?
    super_admin? || sales_manager?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager?

      scope.none
    end
  end
end
