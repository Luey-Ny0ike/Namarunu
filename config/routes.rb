Rails.application.routes.draw do
  resources :inquiries do
  end
  resources :build, controller:'inquiries/build'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

# STATIC PAGES ROUTES
root 'static_pages#index'
get 'products', to: 'static_pages#products', as: 'products'
get '/products/namarunu-store', to: 'static_pages#store-sell', as: 'store_sell'
get 'products/web-administration-services', to: 'static_pages#web-administration', as: 'web_administration'
get 'products/startup-package', to: 'static_pages#startup-package', as: 'startup_package'
get '/pricing', to:'static_pages#pricing', as: 'pricing'
end
