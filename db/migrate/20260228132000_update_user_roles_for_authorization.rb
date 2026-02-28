# frozen_string_literal: true

class UpdateUserRolesForAuthorization < ActiveRecord::Migration[8.2]
  def up
    execute <<~SQL.squish
      UPDATE users
      SET role = 'sales_rep'
      WHERE role IS NULL OR role = 'user'
    SQL

    change_column_default :users, :role, from: "user", to: "sales_rep"
  end

  def down
    execute <<~SQL.squish
      UPDATE users
      SET role = 'user'
      WHERE role = 'sales_rep'
    SQL

    change_column_default :users, :role, from: "sales_rep", to: "user"
  end
end
