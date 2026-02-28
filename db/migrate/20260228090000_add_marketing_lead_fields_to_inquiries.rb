class AddMarketingLeadFieldsToInquiries < ActiveRecord::Migration[8.2]
  def change
    add_column :inquiries, :business_name, :string
    add_column :inquiries, :business_type, :string
    add_column :inquiries, :sell_in_store, :boolean
    add_column :inquiries, :business_link, :string
    add_column :inquiries, :intent, :string
    add_column :inquiries, :source, :string, default: "marketing_get_started", null: false
    add_column :inquiries, :status, :string, default: "new", null: false
    add_column :inquiries, :utm_source, :string
    add_column :inquiries, :utm_medium, :string
    add_column :inquiries, :utm_campaign, :string
    add_column :inquiries, :utm_term, :string
    add_column :inquiries, :utm_content, :string
  end
end
