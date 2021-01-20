source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'aws-sdk-cloudwatchevents'
gem 'aws-sdk-core'
gem 'aws-sdk-ecr'
gem 'aws-sdk-ecs'
gem 'aws-sdk-iam'
gem 'aws-sdk-kms'
gem 'bootsnap', require: false
gem 'config'
gem 'docker-api'
gem 'enumerize'
gem 'git'
gem 'grape'
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
gem 'puma'
gem 'rails', '6.0.3.4'
gem 'redis'
gem 'rest-client'
gem 'sidekiq'
gem 'slack-ruby-bot-server-events'
gem 'tzinfo-data'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'rspec-rails'
  gem 'simplecov', '0.21.1'
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
