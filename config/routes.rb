Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  devise_for :clients, controllers: {
    sessions: 'clients/sessions',
    registrations: 'clients/registrations'
  }
  # Deviseの管理者認証
  devise_for :admins, controllers: {
    sessions: 'admins/sessions',
    registrations: 'admins/registrations'
  }
  
  root to: 'tops#interview'
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
      end
    end
  end


  # GETで /api/interviews/start および start_by_token にアクセスされた場合は面接ページへリダイレクト
  get '/api/interviews/start', to: redirect('/interview')
  get '/api/interviews/start_by_token', to: redirect('/interview')

  namespace :admin do
    resources :interview_results, only: [:index, :show]
  end

  namespace :client do
    resources :interview_results, only: [:index, :show]
    resources :deals do
      resources :user_progresses, only: [:index, :show]
      member do
        get :presentation
      end
    end
  end

  # API for AI responses
  post '/api/ai_response', to: 'api/ai_responses#create'

  # Public Deal Sessions (for users accessing deals via access token)
  namespace :public do
    resource :deal_session, path: 'deal/:token', only: [:show], as: :deal_session do
      post :create_user_info, on: :member
      get :conversation, on: :member
    end
  end
end
