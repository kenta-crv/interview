Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  devise_for :admins, controllers: {
    sessions: "admins/sessions",
    registrations: "admins/registrations",
    passwords: "admins/passwords"
  }
  
  devise_for :clients, controllers: {
    sessions: "clients/sessions",
    registrations: "clients/registrations",
    passwords: "clients/passwords"
  }

  root to: 'tops#index'
  # --- 各ジャンルLPの定義 ---
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

  # 不要になった場合は削除、あるいは管理用として残す場合は保持
  namespace :admin do
    resources :interview_results, only: [:index, :show]
  end

  # API for AI responses
  post '/api/ai_response', to: 'api/ai_responses#create'

  # Public Deal Sessions (for users accessing deals via access token)
  namespace :public do
    resource :deal_session, path: 'deal/:token', only: [:show], as: :deal_session do
      post :create_user_info, on: :member
      get :conversation, on: :member
      get :playback, on: :member
      post :respond, on: :member
      post :evaluate, on: :member
    end
  end


  # --- ダッシュボード機能の集約 ---
  namespace :dashboard do
    get 'index', to: 'dashboard#index', as: :index
    get 'setting', to: 'dashboard#setting', as: :setting
    get 'management', to: 'dashboard#management', as: :management
    root to: 'dashboard#index'
    
    resource :subscription, only: [:show, :update] do
      get :cancel_confirm
      post :cancel
    end
    resources :notifications

    # client から dashboard へ移行したリソース
    resources :interview_results, only: [:index, :show]
    resources :deals do
      resources :user_progresses, only: [:index, :show]
      member do
        get :presentation
        patch :update_content
        post :ai_rewrite
        post :regenerate_audio
        post :publish
        post :reprocess
        post :upload_documents
        get :processing_status
      end
    end

    # 外出しになっていた clients とその子リソースを dashboard 内に移動
    resources :clients do
      resources :push_subscriptions, only: [:index, :create]
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

  post 'stripe/webhook', to: 'stripe_webhooks#create'
  get 'plans', to: 'plans#index', as: :plans
  post 'plans/select', to: 'plans#select', as: :select_plan


  get '/unsubscribe/:token', to: 'unsubscribes#show', as: :unsubscribe
  post '/webhooks/stripe', to: 'webhooks#stripe'
  get '/l/:token', to: 'click_tracking#redirect', as: :click_tracking
end