class CreateInquiries < ActiveRecord::Migration[6.0]
  def change
    create_table :inquiries do |t|
      t.string :full_name
      t.string :phone_number
      t.string :email
      t.string :store_name
      t.string :domain_name
      t.string :preffered_name
      t.string :plan
      t.string :billing_type
      t.string :web_administration

      t.timestamps
    end
  end
end
