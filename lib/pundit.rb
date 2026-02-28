# frozen_string_literal: true

module Pundit
  class NotAuthorizedError < StandardError; end
  class NotDefinedError < StandardError; end

  class PolicyFinder
    attr_reader :object

    def initialize(object)
      @object = object
    end

    def policy!
      policy or raise NotDefinedError, "unable to find policy for #{object.inspect}"
    end

    def policy
      klass_name = "#{namespace_prefix}#{model_name}Policy"
      klass_name.safe_constantize
    end

    private

    def namespace_prefix
      return "" unless object.is_a?(Array) && object.size > 1

      object[0..-2].map { |part| part.to_s.camelize }.join("::") + "::"
    end

    def model_name
      target = model
      return target.to_s.camelize if target.is_a?(Symbol) || target.is_a?(String)
      return target.name if target.is_a?(Class)

      target.class.name
    end

    def model
      object.is_a?(Array) ? object.last : object
    end
  end

  module Authorization
    extend ActiveSupport::Concern

    included do
      helper_method :policy, :policy_scope if respond_to?(:helper_method)
    end

    def authorize(record, query = nil)
      query ||= "#{action_name}?"
      raise NotAuthorizedError unless policy(record).public_send(query)

      record
    end

    def policy(record)
      finder = PolicyFinder.new(record)
      policy_class = finder.policy!
      policy_class.new(pundit_user, pundit_model(record))
    end

    def policy_scope(scope)
      finder = PolicyFinder.new(scope)
      policy_class = finder.policy!
      scope_class = policy_class.const_get(:Scope)
      scope_class.new(pundit_user, pundit_model(scope)).resolve
    end

    private

    def pundit_user
      nil
    end

    def pundit_model(record)
      record.is_a?(Array) ? record.last : record
    end
  end
end
