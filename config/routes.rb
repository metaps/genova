require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web, at: '/sidekiq'
  mount API::Route => '/api'

  root to: 'deploy_jobs#index'
  resources :deploy_jobs, only: %i[index show]
  get '*path', controller: 'application', action: 'render_404'
end
