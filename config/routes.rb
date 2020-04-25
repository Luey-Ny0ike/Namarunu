Rails.application.routes.draw do
  resources :inquiries
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

# STATIC PAGES ROUTES
root 'static_pages#index'
get '/products/namarunu-store', to: 'static_pages#store-sell', as: 'store_sell'
get '/pricing', to:'static_pages#pricing', as: 'pricing'
end
