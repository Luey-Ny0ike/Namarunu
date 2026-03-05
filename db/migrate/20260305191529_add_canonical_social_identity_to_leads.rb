class AddCanonicalSocialIdentityToLeads < ActiveRecord::Migration[8.2]
  def change
    add_column :leads, :instagram_handle, :string
    add_column :leads, :tiktok_handle, :string
    add_column :leads, :facebook_url, :string
    add_column :leads, :instagram_url, :string
    add_column :leads, :tiktok_url, :string

    add_index :leads,
              "lower(instagram_handle)",
              unique: true,
              where: "instagram_handle IS NOT NULL",
              name: "index_leads_on_lower_instagram_handle_unique"
    add_index :leads,
              "lower(tiktok_handle)",
              unique: true,
              where: "tiktok_handle IS NOT NULL",
              name: "index_leads_on_lower_tiktok_handle_unique"
  end
end
