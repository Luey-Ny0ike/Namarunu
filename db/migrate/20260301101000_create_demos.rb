# frozen_string_literal: true

class CreateDemos < ActiveRecord::Migration[8.2]
  def change
    create_table :demos do |t|
      t.references :lead, null: true, foreign_key: true
      t.references :account, null: true, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.integer :duration_minutes, null: false, default: 30
      t.string :status, null: false, default: "scheduled"
      t.string :outcome
      t.text :notes
      t.string :demo_link
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to_user, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :demos, :status
    add_index :demos, :outcome
    add_index :demos, :scheduled_at
    add_index :demos, %i[assigned_to_user_id scheduled_at]
  end
end
