# frozen_string_literal: true

Rails.application.routes.draw do
  get "/login", to: "sessions#new", as: :login
  resource :session, only: [:new, :create, :destroy]
  resource :registration, only: [:new, :create]
  resources :passwords, param: :token, only: [:new, :create, :edit, :update]
  get "/leads", to: redirect("/app/leads"), as: :legacy_leads_index
  resources :inquiries do
    collection do
      get :won_deals
    end

    member do
      patch :reassign_checkout
    end
  end
  resources :leads, only: %i[show new create edit update] do
    collection do
      get :my_tasks
    end

    member do
      post :convert
      post :book_demo
      patch :checkout
      patch :release
      patch :force_release
      patch :reassign_checkout
      post :log_call_attempt
    end
  end
  resources :accounts, only: %i[show]
  resources :demos, only: %i[show update]
  resources :build, controller: 'inquiries/build'

  namespace :admin do
    resources :users, only: %i[index update]
  end

  namespace :finance do
    resources :payouts, only: :index
  end

  namespace :app do
    root "dashboard#show"
    resources :demos, only: %i[index show] do
      member do
        post :complete
      end
    end
    get "leads/new", to: "leads#new", as: :new_lead
    resources :leads, only: %i[index show create edit update] do
      member do
        post :log_attempt, to: "lead_actions#log_attempt"
        post :book_demo, to: "lead_actions#book_demo"
        post :mark_awaiting_commitment, to: "lead_actions#mark_awaiting_commitment"
        post :mark_invoice_sent, to: "lead_actions#mark_invoice_sent"
        post :mark_lost, to: "lead_actions#mark_lost"
        post :confirm_payment, to: "lead_actions#confirm_payment"
        post :release_and_next, to: "lead_actions#release_and_next"
      end
    end
    resource :work_queue, only: :show, controller: :work_queue do
      post :pull
    end
  end

  namespace :contribute do
    resources :submissions, except: :destroy
    root "submissions#new"
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
