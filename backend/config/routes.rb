Rails.application.routes.draw do
  namespace :reports do
    get :overview
    get :by_agent
    get :by_tag
    get :export
    get :performance
  end
  resources :agents do
    member do
      patch :block
      patch :unblock
      patch :toggle_roundrobin
    end
    collection do
      get :queue
    end
  end
  resources :round_robin_groups, only: %i[index create update destroy]
  resources :pipelines, only: %i[index create update destroy] do
    resources :pipeline_stages, only: %i[create]
    resources :pipeline_cards, only: %i[index create]
  end
  resources :pipeline_stages, only: %i[update destroy] do
    resources :pipeline_triggers, only: %i[create]
  end
  resources :pipeline_triggers, only: %i[update destroy]
  resources :pipeline_cards, only: %i[index update destroy]
  resources :regua_triggers, only: %i[index create update destroy]
  resources :contacts do
    member do
      post :merge
      post :add_note
      patch :block
      patch :unblock
    end
    collection do
      get :ativas
      patch :bulk_assign
    end
    resources :tags, only: [:index, :create, :destroy], controller: 'contact_tags'
  end
  resources :tarefas, only: [:index, :create, :update, :destroy] do
    member { patch :complete }
  end
  resources :agendamentos, only: [:index, :create, :update, :destroy] do
    collection { get :resumo }
  end
  resources :tags
  get 'dashboard', to: 'dashboard#index'
  
  resources :conversations, only: [:index, :show, :create, :update] do
    resources :messages, only: [:index, :create]
    resources :scheduled_messages, only: [:index, :create, :destroy]
    resources :tags, only: [:index, :create, :destroy], controller: 'conversation_tags'
    member do
      post :generate_summary
      get :ai_status
      post :resume_ai
      get :transcript
    end
  end

  resources :internal_messages, only: [:index, :create] do
    collection { get :threads }
  end

  patch 'profile/avatar', to: 'profile#update_avatar'
  delete 'profile/avatar', to: 'profile#destroy_avatar'

  resources :notifications, only: [:index] do
    collection do
      put :mark_all_read
    end
    member do
      put :mark_as_read
    end
  end

  resource :account, only: [:show, :update] do
    put :update_password
  end

  get  'jueri/debug',     to: 'jueri#debug'
  get  'jueri/debug/:id', to: 'jueri#debug_show'
  post 'jueri/sync-now',  to: 'jueri#sync_now'
  get  'jueri/debug_schema', to: 'jueri#debug_schema'

  resources :inboxes do
    resources :members, controller: 'inbox_members', only: [:index, :create, :destroy]
    member do
      get :qr_code
      get :status
      post :disconnect
      post :generate_prompt
    end
  end

  resources :sales_teams, only: [:index] do
    member do
      patch :members, action: :update_members
    end
  end

  get  'instagram_oauth/authorize_url',      to: 'instagram_oauth#authorize_url'
  get  'instagram_oauth/callback',           to: 'instagram_oauth#callback'
  get  'facebook_leads_oauth/authorize_url', to: 'facebook_leads_oauth#authorize_url'
  get  'facebook_leads_oauth/callback',      to: 'facebook_leads_oauth#callback'
  post 'facebook_leads_oauth/disconnect',    to: 'facebook_leads_oauth#disconnect'

  namespace :webhooks do
    post 'baileys',              to: 'baileys#create'
    post 'stripe',               to: 'stripe#create'
    get  'instagram',            to: 'instagram#verify'
    post 'instagram',            to: 'instagram#create'
    get  'facebook_leads',       to: 'facebook_leads#verify'
    post 'facebook_leads',       to: 'facebook_leads#create'
    post 'jueri/:token',         to: 'jueri#create'
  end

  get  'push_subscriptions/vapid_public_key', to: 'push_subscriptions#vapid_public_key'
  post 'push_subscriptions',                  to: 'push_subscriptions#create'
  delete 'push_subscriptions/unsubscribe',    to: 'push_subscriptions#unsubscribe'

  # Sem self-signup público: deploy dedicado só da Clara, não uma SaaS
  # multi-tenant onde qualquer um cria uma "empresa" nova (ver commit que
  # removeu RegistrationsController/Users::RegistrationsController/console admin).
  devise_for :users, skip: [:registrations], controllers: {
    sessions: 'users/sessions',
    passwords: 'users/passwords'
  }

  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => '/cable'
end
