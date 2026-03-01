# frozen_string_literal: true

class DemoPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || sales_rep?
  end

  def show?
    manageable_by_user?
  end

  def create?
    return true if super_admin? || sales_manager?
    return false unless sales_rep?

    assignee_id = record.assigned_to_user_id || user.id
    creator_id = record.created_by_user_id || user.id
    assignee_id == user.id && creator_id == user.id
  end

  def update?
    manageable_by_user?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager?
      return scope.none unless user&.sales_rep?

      scope.where(assigned_to_user_id: user.id).or(scope.where(created_by_user_id: user.id))
    end
  end

  private

  def manageable_by_user?
    return true if super_admin? || sales_manager?
    return false unless sales_rep?

    record.assigned_to_user_id == user.id || record.created_by_user_id == user.id
  end
end
