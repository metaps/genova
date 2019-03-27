source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'aws-sdk', '~> 3.0.0'
gem 'bootsnap'
gem 'config'
gem 'docker-api'
gem 'ecs_deployer', '2.1.13'
gem 'enumerize'

gem 'font-awesome-rails'
gem 'foundation-rails', '~> 6.3.1'

gem 'git'
gem 'grape', '~> 1.1.0'
gem 'grape_logging'
gem 'health_check'
gem 'highline'
gem 'jquery-rails'
gem 'kaminari-actionview'
gem 'kaminari-mongoid'
gem 'mongoid'
gem 'mongoid-scroll'
gem 'octokit'
gem 'oj'
gem 'puma', '~> 3.12.0'
gem 'puma_worker_killer'
gem 'rails', '~> 5.2.2.1'
gem 'redis'
gem 'rest-client'
gem 'sass-rails'
gem 'sidekiq'
gem 'slack-ruby-bot-server'
gem 'tzinfo-data'
gem 'uglifier'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'rspec-rails'
  gem 'simplecov'
end

group :test do
  # http://qiita.com/Anorlondo448/items/95946ebb071a4c3500fb
  gem 'rspec-sidekiq'
  gem 'vcr'
  gem 'webmock'
end

group :development do
  # gem 'web-console'
  # gem 'listen'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'json_spec'
  gem 'rubocop'
  gem 'spring'
  gem 'spring-watcher-listen'
end
