# frozen_string_literal: true

class Account
  include ActiveModel::Model

  attr_accessor :converted

  def converted?
    converted == true
  end
end
