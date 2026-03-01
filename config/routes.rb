# frozen_string_literal: true

Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  resource :registration, only: [:new, :create]
  resources :passwords, param: :token, only: [:new, :create, :edit, :update]
  resources :inquiries do
    collection do
      get :won_deals
    end

    member do
      patch :reassign_checkout
    end
  end
  resources :leads, only: %i[index show new create edit update] do
    collection do
      get :my_tasks
    end

    member do
      post :book_demo
      patch :checkout
      patch :release
      patch :force_release
      patch :reassign_checkout
      post :log_call_attempt
    end
  end
  resources :demos, only: %i[show update]
  resources :build, controller: 'inquiries/build'

  namespace :admin do
    resources :users, only: %i[index update]
  end

  namespace :finance do
    resources :payouts, only: :index
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  # STATIC PAGES ROUTES
  root 'static_pages#index'
  get 'products', to: 'static_pages#products', as: 'products'
  get '/products/namarunu-store', to: 'static_pages#store-sell', as: 'store_sell'
  get 'products/web-administration-services', to: 'static_pages#web-administration', as: 'web_administration'
  get 'products/startup-package', to: 'static_pages#startup-package', as: 'startup_package'
  get '/pricing', to: 'static_pages#pricing', as: 'pricing'
end
