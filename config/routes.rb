Rails.application.routes.draw do
  devise_for :users, controllers: { invitations: 'users/invitations' }
  # Gallery routes (main UI)
  resources :gallery, only: [:index, :show] do
    collection do
      get :day_sessions
      post :toggle_hide_heroes
    end
    member do
      post :update_hero
      post :save_email
      patch :reject_photo
      post :split_session
      patch :hide_session
      get :download_all
      get :download_photo
      get :download_test
    end
  end

  # User-friendly session/photo URLs
  get 'session/:id', to: 'gallery#show', as: :session
  get 'session/:session_id/photo/:photo_position', to: 'gallery#show', as: :session_photo
  
  # API routes for Vue frontend (keeping for compatibility)
  namespace :api do
    resources :sessions, only: [:index, :show] do
      member do
        put :update_hero
      end
    end
    resources :sittings, only: [:create, :show, :update]
    resources :photos, only: [] do
      member do
        post :extract_exif
      end
      collection do
        get :exif_config
        get :random_hero_faces
      end
    end
    resources :photo_sessions, only: [] do
      member do
        patch :tags, to: 'photo_sessions#update_tags'
        patch :gender, to: 'photo_sessions#update_gender'
        patch :quality, to: 'photo_sessions#update_quality'
        delete 'tags/clear', to: 'photo_sessions#clear_tags'
      end
    end
  end
  
  # Admin routes
  namespace :admin do
    get 'dashboard', to: 'dashboard#index'
    post 'warm_stats_cache', to: 'dashboard#warm_stats_cache'
    get 'export_emails', to: 'dashboard#export_emails'
    get 'thumbnails', to: 'thumbnails#index'
    get 'help', to: 'help#show'
    resources :invites, only: [:index, :new, :create, :destroy] do
      member do
        post :resend
      end
    end
    resources :sessions, only: [:index]
    resources :sittings, only: [:index]
    resources :exif_config, only: [:index, :update] do
      collection do
        post :reset
      end
    end
  end
  
  # Face detection admin
  get 'admin', to: 'admin#index'
  get 'admin/face_detection', to: 'admin#face_detection'
  get 'admin/queue_status', to: 'admin#queue_status'
  post 'admin/enqueue_all', to: 'admin#enqueue_all'
  post 'admin/enqueue_session/:session_id', to: 'admin#enqueue_session', as: 'admin_enqueue_session'
  post 'admin/retry_failed', to: 'admin#retry_failed'
  post 'admin/clear_completed_jobs', to: 'admin#clear_completed_jobs'
  post 'admin/pause_queue', to: 'admin#pause_queue'
  
  # Mobile email collection
  namespace :mobile do
    resources :sittings, only: [:new, :create]
  end
  
  # Static photo serving
  get '/photos/*path', to: 'photos#serve', format: false, as: :photo
  
  # Stats page
  get 'stats', to: 'stats#index', as: :stats
  
  # Heroes page (public)
  resources :heroes, only: [:index, :show]
  
  # Preloader for offline caching
  get 'preloader', to: 'preloader#index'
  post 'preloader/complete', to: 'preloader#complete'
  post 'preloader/skip', to: 'preloader#skip'
  get 'preloader/variant_urls', to: 'preloader#variant_urls'
  get 'preloader/all_photo_metadata', to: 'preloader#all_photo_metadata'
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Root path - now points to gallery
  root to: 'gallery#index'
end
