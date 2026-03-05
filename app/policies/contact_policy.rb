# frozen_string_literal: true

class ContactPolicy < ApplicationPolicy
  def create?
    return true if super_admin? || sales_manager?

    sales_rep? && owns_customer?
  end

  def update?
    return true if super_admin? || sales_manager?

    sales_rep? && owns_customer?
  end

  def destroy?
    return true if super_admin? || sales_manager?

    sales_rep? && owns_customer?
  end

  private

  def owns_customer?
    record.account.owner_user_id == user&.id
  end
end
