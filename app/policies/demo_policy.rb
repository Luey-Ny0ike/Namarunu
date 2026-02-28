# frozen_string_literal: true

class DemoPolicy < ApplicationPolicy
  def index?
    super_admin? || sales_manager? || support?
  end

  def show?
    return true if super_admin? || sales_manager?
    return false unless support?

    record.account&.converted?
  end

  def update?
    super_admin? || sales_manager?
  end
end
