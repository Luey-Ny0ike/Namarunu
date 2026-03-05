# frozen_string_literal: true

class NormalizeActivityActionTypesAndMetadata < ActiveRecord::Migration[8.2]
  class MigrationActivity < ApplicationRecord
    self.table_name = "activities"
  end

  def up
    normalize_action_types!
    normalize_status_changed_metadata!
    normalize_call_logged_metadata!
  end

  def down
    MigrationActivity.where(action_type: "call_logged").update_all(action_type: "call_attempt_logged")
    MigrationActivity.where(action_type: "status_changed").update_all(action_type: "lead_status_changed")
  end

  private

  def normalize_action_types!
    MigrationActivity.where(action_type: "call_attempt_logged").update_all(action_type: "call_logged")
    MigrationActivity.where(action_type: "lead_status_changed").update_all(action_type: "status_changed")
  end

  def normalize_status_changed_metadata!
    MigrationActivity.where(action_type: "status_changed").find_each do |activity|
      metadata = (activity.metadata || {}).deep_stringify_keys
      normalized_metadata = metadata.except("old", "new", "status")

      from = metadata["from"].presence || metadata["old"].presence
      to = metadata["to"].presence || metadata["new"].presence || metadata["status"].presence

      normalized_metadata["from"] = from if from.present?
      normalized_metadata["to"] = to if to.present?

      next if normalized_metadata == metadata

      activity.update_columns(metadata: normalized_metadata, updated_at: Time.current)
    end
  end

  def normalize_call_logged_metadata!
    MigrationActivity.where(action_type: "call_logged").find_each do |activity|
      metadata = (activity.metadata || {}).deep_stringify_keys
      normalized_metadata = metadata.except("notes_present")
      next if normalized_metadata == metadata

      activity.update_columns(metadata: normalized_metadata, updated_at: Time.current)
    end
  end
end
