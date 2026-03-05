# frozen_string_literal: true

json.extract! inquiry, :id, :full_name, :phone_number, :email, :store_name, :domain_name, :preffered_name, :plan,
              :billing_type, :web_administration, :created_at, :updated_at
json.url app_inquiry_url(inquiry, format: :json)
