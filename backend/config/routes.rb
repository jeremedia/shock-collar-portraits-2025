Rails.application.routes.draw do
  # Gallery routes (main UI)
  resources :gallery, only: [:index, :show] do
    member do
      post :update_hero
      post :save_email
      patch :reject_photo
      post :split_session
    end
  end
  
  # API routes for Vue frontend (keeping for compatibility)
  namespace :api do
    resources :sessions, only: [:index, :show] do
      member do
        put :update_hero
      end
    end
    resources :sittings, only: [:create, :show, :update]
  end
  
  # Admin routes
  namespace :admin do
    root to: 'dashboard#index'
    get 'export_emails', to: 'dashboard#export_emails'
    resources :sessions, only: [:index]
    resources :sittings, only: [:index]
  end
  
  # Mobile email collection
  namespace :mobile do
    resources :sittings, only: [:new, :create]
  end
  
  # Static photo serving
  get '/photos/*path', to: 'photos#serve', format: false, as: :photo
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Root path - now points to gallery
  root to: 'gallery#index'
end
