Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  devise_for :admins, skip: [:registrations], controllers: {
    sessions: "admins/sessions",
    passwords: "admins/passwords"
  }

  devise_for :clients, controllers: {
    sessions: "clients/sessions",
    registrations: "clients/registrations",
    passwords: "clients/passwords"
  }

  root to: 'tops#index'
  # --- Meetia LP (single page; legacy paths redirect to anchors) ---
  get 'whats', to: redirect('/#whats')
  get 'service', to: redirect('/#service')
  get 'features', to: redirect('/#features')
  get 'pricing', to: redirect('/#pricing')
  get 'reviews', to: redirect('/#reviews')
  get 'faq', to: redirect('/#faq')
  get 'company', to: redirect('/#company')
  get 'interview', to: 'tops#interview'


  # --- 面接シナリオ管理 ---
  resources :situations do
    resources :questions, except: [:show]
  end

  # --- Sidekiq Web UI ---
  require 'sidekiq/web'
  authenticate :admin do
    mount Sidekiq::Web, at: "/sidekiq"
  end

  # --- AI Interview System API ---
  namespace :api do
    resources :interviews, only: [] do
      member do
        get :next_question
        post :submit_answer
        post :answer, action: :submit_answer
        post :complete
        get :status
        post :resume
      end
      collection do
        post :start
        post :start_by_token
      end
    end

    # --- AI Deal System API ---
    resources :deals, only: [:index, :show, :create] do
      member do
        post :upload_documents
        post :upload_audio
        post :generate_speech
        post :start_presentation
        post :submit_choice
        post :process_pdf
        post :ai_rewrite_page
        post :regenerate_page_audio
      end
    end
  end


  # GETで /api/interviews/start および start_by_token にアクセスされた場合は面接ページへリダイレクト
  get '/api/interviews/start', to: redirect('/interview')
  get '/api/interviews/start_by_token', to: redirect('/interview')

  namespace :admin do
    resources :interview_results, only: [:index, :show]
  end

  # Public Deal Sessions (for users accessing deals via access token)
  namespace :public do
    resource :deal_session, path: 'deal/:token', only: [:show], as: :deal_session do
      post :create_user_info, on: :member
      get :conversation, on: :member
      get :playback, on: :member
      post :respond, on: :member
      post :evaluate, on: :member
      post :track_event, on: :member
    end
  end


  # --- ダッシュボード機能の集約 ---
  namespace :dashboard do
    get 'index', to: 'dashboard#index', as: :index
    root to: 'dashboard#index'

    resource :account, only: [:show, :update]
    get "management", to: "management#index", as: :management
    resource :subscription, only: [:show, :update] do
      get :cancel_confirm
      post :cancel
    end
    resources :notifications

    resources :interview_results, only: [:index, :show]
    resources :deals do
      resources :user_progresses, only: [:index, :show]
      resources :deal_faqs, only: [:create, :update, :destroy] do
        member do
          post :skip
        end
        collection do
          post :analyze_gaps
          post :suggest_from_events
          post :stress_test
        end
      end
      member do
        get :presentation
        patch :update_content
        post :ai_rewrite
        post :regenerate_audio
        post :publish
        post :reprocess
        post :reset_processing
        post :upload_documents
        post :upload_supplement_documents
        patch :update_presentation_settings
        patch :update_follow_up_settings
        get :processing_status
      end
    end
  end

  namespace :admin do
    root to: redirect('/dashboard/index')
    resources :notifications
  end


  # --- 決済・外部連携・その他 ---
  get 'checkout/confirmation', to: 'checkout#confirmation', as: :checkout_confirmation
  post 'checkout/create', to: 'checkout#create', as: :checkout_create
  get 'checkout/success', to: 'checkout#success', as: :checkout_success
  get 'checkout/cancel', to: 'checkout#cancel', as: :checkout_cancel

  get 'plans', to: 'plans#index', as: :plans
  post 'plans/select', to: 'plans#select', as: :select_plan

  get '/unsubscribe/:token', to: 'unsubscribes#show', as: :unsubscribe
  get '/follow_up/o/:token', to: 'public/follow_up_tracking#open', as: :follow_up_open
  get '/follow_up/c/:token', to: 'public/follow_up_tracking#click', as: :follow_up_click
  get '/follow_up/unsubscribe/:token', to: 'public/follow_up_tracking#unsubscribe', as: :follow_up_unsubscribe
  post '/webhooks/stripe', to: 'webhooks#stripe'
  get '/l/:token', to: 'click_tracking#redirect', as: :click_tracking
end
