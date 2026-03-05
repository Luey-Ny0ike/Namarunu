# frozen_string_literal: true

class BackfillAccountsFromConvertedLeads < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    updated_accounts = 0

    Account.where.not(converted_from_lead_id: nil).find_each(batch_size: 200) do |account|
      lead = Lead.find_by(id: account.converted_from_lead_id)
      next if lead.blank?

      updates = {}
      updates[:industry] = lead.industry if account.industry.blank? && lead.industry.present?
      updates[:location] = lead.location if account.location.blank? && lead.location.present?
      updates[:instagram_handle] = lead.instagram_handle if account.instagram_handle.blank? && lead.instagram_handle.present?
      updates[:instagram_url] = lead.instagram_url if account.instagram_url.blank? && lead.instagram_url.present?
      updates[:tiktok_handle] = lead.tiktok_handle if account.tiktok_handle.blank? && lead.tiktok_handle.present?
      updates[:tiktok_url] = lead.tiktok_url if account.tiktok_url.blank? && lead.tiktok_url.present?
      updates[:facebook_url] = lead.facebook_url if account.facebook_url.blank? && lead.facebook_url.present?
      updates[:owner_user_id] = lead.owner_user_id if account.owner_user_id.blank? && lead.owner_user_id.present?
      updates[:status] = "pending" if account.status.blank?

      next if updates.empty?

      account.update!(updates)
      updated_accounts += 1
    end

    puts "Backfilled accounts: #{updated_accounts}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Backfill is data-only and cannot be safely reversed"
  end
end
