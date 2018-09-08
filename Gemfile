source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'aws-sdk', '~> 3.0.0'
gem 'config'
gem 'docker-api'
gem 'ecs_deployer', '2.1.9'
gem 'enumerize'

gem 'font-awesome-rails'
# https://github.com/zurb/foundation-sites/issues/10379
gem 'foundation-rails', '~> 6.3.1'

gem 'git'
gem 'grape'
gem 'grape_logging'
gem 'highline'
gem 'jquery-rails'
gem 'kaminari-actionview'
gem 'kaminari-mongoid'
gem 'mongoid'
gem 'mongoid-scroll'
gem 'octokit'
gem 'oj'
gem 'puma', '~> 3.0'
gem 'rails', '~> 5.1.3'
gem 'redis'
gem 'rest-client'
gem 'sass-rails'
gem 'sidekiq'
gem 'sidekiq-limit_fetch'
gem 'slack-ruby-bot-server'
gem 'therubyracer', platforms: :ruby
gem 'uglifier', '>= 1.3.0'

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
  # gem 'web-console', '>= 3.3.0'
  # gem 'listen', '~> 3.0.5'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'json_spec'
  gem 'rubocop'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end
