# frozen_string_literal: true

class AddMatchOutcomeToLeadSubmissions < ActiveRecord::Migration[8.2]
  def change
    add_column :lead_submissions, :match_outcome, :string
    add_column :lead_submissions, :matched_field, :string

    add_index :lead_submissions, :match_outcome
  end
end
