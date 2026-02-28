# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    def index
      authorize([:admin, User])
      @users = policy_scope([:admin, User]).order(created_at: :desc)
    end

    def update
      @user = User.find(params[:id])
      authorize([:admin, @user])

      if @user.update(user_params)
        redirect_to admin_users_path, notice: "User role updated."
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def user_params
      params.expect(user: [:role])
    end
  end
end
