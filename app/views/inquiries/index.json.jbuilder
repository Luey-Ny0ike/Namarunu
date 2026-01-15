# frozen_string_literal: true

json.array! @inquiries, partial: 'inquiries/inquiry', as: :inquiry
