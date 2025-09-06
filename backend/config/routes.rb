Rails.application.routes.draw do
  # API routes for Vue frontend
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
  
  # Static photo serving (until Active Storage is configured)
  get '/photos/*path', to: 'photos#serve', format: false
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Root path
  root to: redirect('/admin')
end
