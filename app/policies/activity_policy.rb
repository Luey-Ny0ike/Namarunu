# frozen_string_literal: true

class ActivityPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager?
  end

  def show?
    index?
  end

  def create?
    super_admin? || sales_manager?
  end

  def update?
    super_admin? || sales_manager?
  end
end
