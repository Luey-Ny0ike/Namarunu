# frozen_string_literal: true

class CreateCrmLeadsAndActivities < ActiveRecord::Migration[8.2]
  def change
    create_table :leads do |t|
      t.string :business_name, null: false
      t.string :location
      t.string :industry
      t.string :source
      t.string :status, null: false, default: "new"
      t.string :temperature, null: false, default: "warm"
      t.datetime :next_action_at
      t.datetime :last_contacted_at
      t.references :owner_user, null: true, foreign_key: { to_table: :users }
      t.datetime :converted_at

      t.timestamps
    end

    add_index :leads, :status
    add_index :leads, :temperature
    add_index :leads, :next_action_at

    create_table :lead_contacts do |t|
      t.references :lead, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.string :role
      t.string :preferred_channel

      t.timestamps
    end

    create_table :activities do |t|
      t.references :actor_user, null: false, foreign_key: { to_table: :users }
      t.references :subject, polymorphic: true, null: false
      t.string :action_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :activities, :occurred_at
    add_index :activities, :action_type
    add_index :activities, :metadata, using: :gin
  end
end
