# frozen_string_literal: true

class CreateLeadSubmissions < ActiveRecord::Migration[8.2]
  def change
    create_table :lead_submissions do |t|
      t.string :business_name, null: false
      t.string :instagram_url
      t.string :instagram_handle
      t.string :tiktok_url
      t.string :tiktok_handle
      t.string :phone_raw
      t.string :phone_normalized
      t.string :location
      t.text :notes
      t.references :submitted_by_user, null: false, foreign_key: { to_table: :users }
      t.references :lead, null: true, foreign_key: true
      t.datetime :editable_until, null: false, default: -> { "(CURRENT_TIMESTAMP + interval '30 minutes')" }
      t.datetime :locked_at

      t.timestamps
    end

    add_index :lead_submissions, :instagram_handle
    add_index :lead_submissions, :tiktok_handle
    add_index :lead_submissions, :phone_normalized
  end
end
