source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'aws-sdk-core'
gem 'aws-sdk-ecr'
gem 'aws-sdk-ecs'
gem 'aws-sdk-eventbridge'
gem 'aws-sdk-iam'
gem 'aws-sdk-kms'
gem 'bootsnap', require: false
gem 'config'
gem 'deep_merge', require: 'deep_merge/rails_compat'
gem 'docker-api'
gem 'enumerize'

# When using git with Sidekiq, errors may occur because it is not thread safe.
# Until the issue is fixed, the policy is to use the thread-safe fork version.
# https://github.com/metaps/genova/issues/369
gem 'git', git: 'https://github.com/fxposter/ruby-git', branch: 'remove-chdir'

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
gem 'oj'
gem 'puma'
gem 'rails', '~> 7.0.5'
gem 'redis'
gem 'rest-client'
gem 'sassc-rails'
gem 'sidekiq'
gem 'slack-ruby-bot-server-events'
gem 'strings-truncation'

# sprockets 4.0.0以降はsprocketsを使わない場合もmanifest.jsを求められるため、バージョンを固定化する。
# https://qiita.com/sasakura_870/items/106484f88c857bd9563e
gem 'sprockets', '~> 3.7.2'

gem 'tzinfo-data'
gem 'vite_rails'

group :development, :test do
  gem 'rspec-rails'
  gem 'simplecov', '~> 0.17.1'
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
