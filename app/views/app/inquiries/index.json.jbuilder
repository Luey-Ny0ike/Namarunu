# frozen_string_literal: true

json.array! @inquiries, partial: "app/inquiries/inquiry", as: :inquiry
