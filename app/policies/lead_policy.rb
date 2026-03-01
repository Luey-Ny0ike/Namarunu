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

    record.editable_by?(user)
  end

  def destroy?
    super_admin?
  end

  def checkout?
    super_admin? || sales_manager? || sales_rep?
  end

  def release?
    super_admin? || sales_manager? || record.checked_out_by?(user)
  end

  def force_release?
    super_admin? || sales_manager?
  end

  def reassign_checkout?
    super_admin? || sales_manager?
  end

  def convert?
    update? && record.conversion_eligible? && record.converted_account.blank?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.super_admin? || user&.sales_manager?
      if user&.sales_rep?
        return scope
          .left_outer_joins(:lead_assignments)
          .where(owner_user_id: user.id)
          .or(
            scope
              .left_outer_joins(:lead_assignments)
              .where(lead_assignments: { user_id: user.id, released_at: nil })
              .where("lead_assignments.expires_at > ?", Time.current)
          )
          .distinct
      end

      scope.none
    end
  end
end
