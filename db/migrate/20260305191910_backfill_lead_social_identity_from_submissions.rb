class BackfillLeadSocialIdentityFromSubmissions < ActiveRecord::Migration[8.2]
  class MigrationLead < ActiveRecord::Base
    self.table_name = "leads"
  end

  class MigrationLeadSubmission < ActiveRecord::Base
    self.table_name = "lead_submissions"
  end

  def up
    counts = {
      leads_updated: 0,
      instagram_handles_backfilled: 0,
      tiktok_handles_backfilled: 0,
      instagram_urls_backfilled: 0,
      tiktok_urls_backfilled: 0,
      instagram_uniqueness_skipped: 0,
      tiktok_uniqueness_skipped: 0,
      record_not_unique_skipped: 0
    }

    say_with_time("Backfilling lead social identity from latest lead submissions") do
      MigrationLead.find_each do |lead|
        latest_submission = MigrationLeadSubmission.where(lead_id: lead.id)
                                                   .order(created_at: :desc, id: :desc)
                                                   .first

        current_instagram_handle = normalize_handle(lead.instagram_handle)
        current_tiktok_handle = normalize_handle(lead.tiktok_handle)

        candidate_instagram_handle = current_instagram_handle
        candidate_tiktok_handle = current_tiktok_handle
        updates = {}

        if candidate_instagram_handle.blank?
          from_submission = normalize_handle(latest_submission&.instagram_handle)
          if from_submission.present?
            if handle_taken?(:instagram_handle, from_submission, lead.id)
              counts[:instagram_uniqueness_skipped] += 1
            else
              candidate_instagram_handle = from_submission
              updates[:instagram_handle] = from_submission
              counts[:instagram_handles_backfilled] += 1
            end
          end
        end

        if candidate_tiktok_handle.blank?
          from_submission = normalize_handle(latest_submission&.tiktok_handle)
          if from_submission.present?
            if handle_taken?(:tiktok_handle, from_submission, lead.id)
              counts[:tiktok_uniqueness_skipped] += 1
            else
              candidate_tiktok_handle = from_submission
              updates[:tiktok_handle] = from_submission
              counts[:tiktok_handles_backfilled] += 1
            end
          end
        end

        if lead.instagram_url.to_s.strip.blank? && candidate_instagram_handle.present?
          updates[:instagram_url] = "https://www.instagram.com/#{candidate_instagram_handle}/"
          counts[:instagram_urls_backfilled] += 1
        end

        if lead.tiktok_url.to_s.strip.blank? && candidate_tiktok_handle.present?
          updates[:tiktok_url] = "https://www.tiktok.com/@#{candidate_tiktok_handle}"
          counts[:tiktok_urls_backfilled] += 1
        end

        next if updates.empty?

        updates[:updated_at] = Time.current if MigrationLead.column_names.include?("updated_at")

        begin
          lead.update_columns(updates)
          counts[:leads_updated] += 1
        rescue ActiveRecord::RecordNotUnique
          counts[:record_not_unique_skipped] += 1
          Rails.logger.warn("BackfillLeadSocialIdentityFromSubmissions skipped lead_id=#{lead.id} due to unique index conflict")
        end
      end
    end

    say "Lead social backfill summary: #{counts}"
    Rails.logger.info("BackfillLeadSocialIdentityFromSubmissions summary: #{counts}")
  end

  def down
    # Data migration only; intentionally irreversible.
  end

  private

  def normalize_handle(value)
    value.to_s.strip.gsub(/\A@+/, "").downcase.presence
  end

  def handle_taken?(column, handle, lead_id)
    MigrationLead.where("lower(#{column}) = ?", handle.downcase)
                 .where.not(id: lead_id)
                 .exists?
  end
end
