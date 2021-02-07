require 'sidekiq/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web, at: '/sidekiq'
  mount Api::Route => '/api'

  health_check_routes

  root to: 'deploy_jobs#index'
  resources :deploy_jobs, only: %i[index show] do
  end
  get 'latest_deployment', controller: :latest_deployment, action: :index
  get '*path', controller: 'application', action: 'render_404'
end
