source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'aws-sdk', '~> 3.0.1'
gem 'bootsnap', require: false
gem 'config'
gem 'docker-api'
gem 'ecs_deployer', '~> 2.3.1'
gem 'enumerize'
gem 'git'
gem 'grape', '~> 1.1.0'
gem 'grape_logging'
gem 'hash_validator'
gem 'health_check'
gem 'highline'
gem 'json-schema'
gem 'kaminari-actionview'
gem 'kaminari-mongoid'
gem 'mongoid'
gem 'mongoid-scroll'
gem 'octokit'
gem 'oj'
gem 'puma', '~> 3.12.1'
gem 'puma_worker_killer'
gem 'rails', '~> 5.2.2.1'
gem 'redis'
gem 'rest-client'
gem 'sidekiq'
gem 'slack-ruby-bot-server', '~> 0.11.1'
gem 'tzinfo-data'

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
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'json_spec'
  gem 'rubocop'
  gem 'spring'
  gem 'spring-watcher-listen'
end
