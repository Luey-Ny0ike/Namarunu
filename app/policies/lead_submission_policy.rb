# frozen_string_literal: true

class LeadSubmissionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.none if user.blank?
      return scope.all if super_admin?

      scope.where(submitted_by_user_id: user.id)
    end

    private

    def super_admin?
      user.super_admin?
    end
  end

  def index?
    contributor_portal_user?
  end

  def show?
    super_admin? || own_submission?
  end

  def create?
    contributor_portal_user?
  end

  def update?
    super_admin? || own_submission?
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  def own_submission?
    user.present? && record.submitted_by_user_id == user.id
  end

  def contributor_portal_user?
    user.present? && (lead_contributor? || sales_manager? || super_admin?)
  end
end
