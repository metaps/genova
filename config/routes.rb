require 'sidekiq/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'logs#index'

  mount Sidekiq::Web, at: '/sidekiq'
  mount API::Route => '/'

  resources :logs, only: %i[index show]

  get '*path', controller: 'application', action: 'render_404'
end
