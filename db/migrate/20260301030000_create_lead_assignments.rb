# frozen_string_literal: true

class CreateLeadAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table :lead_assignments do |t|
      t.references :lead, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :checked_out_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :released_at
      t.string :release_reason

      t.timestamps
    end

    add_index :lead_assignments, :expires_at
    add_index :lead_assignments, :released_at
    add_index :lead_assignments, [:lead_id, :released_at]
    add_index :lead_assignments, :lead_id,
              unique: true,
              where: "released_at IS NULL",
              name: "index_lead_assignments_on_lead_id_unreleased"
  end
end
