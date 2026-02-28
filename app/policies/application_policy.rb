# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def super_admin?
    user&.super_admin? == true
  end

  def sales_manager?
    user&.sales_manager? == true
  end

  def sales_rep?
    user&.sales_rep? == true
  end

  def support?
    user&.support? == true
  end

  def finance?
    user&.finance? == true
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end
  end
end
