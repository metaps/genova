# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] = 'test'

require File.expand_path('../config/environment', __dir__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migration and applies them before tests are run.
# If you are not using ActiveRecord, you can remove this line.

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  Aws.config[:stub_responses] = true

  config.before do
    allow(Settings.github).to receive(:repositories).and_return(
      [
        {
          name: 'repository'
        }
      ]
    )
  end
end

shared_context 'load code_manager_mock' do
  let(:deploy_config) do
    Genova::Config::DeployConfig.new(
      clusters: [
        {
          name: 'cluster',
          services: {
            service: {
              containers: [{ name: 'rails', 'build': {} }],
              path: 'path'
            }
          }
        }
      ]
    )
  end
  let(:task_definition_config) do
    Genova::Config::TaskDefinitionConfig.new(
      container_definitions: [
        {
          name: 'nginx',
          image: 'xxx/nginx:revision_tag'
        }
      ]
    )
  end
  let(:code_manager_mock) { double(Genova::CodeManager::Git) }
  let(:branch_mock) { double(Git::Branch) }

  before do
    allow(code_manager_mock).to receive(:load_deploy_config).and_return(deploy_config)
    allow(code_manager_mock).to receive(:load_task_definition_config).and_return(task_definition_config)
    allow(code_manager_mock).to receive(:base_path).and_return('base_path')
    allow(code_manager_mock).to receive(:repos_path).and_return('repos_path')
    allow(code_manager_mock).to receive(:task_definition_config_path)
    allow(code_manager_mock).to receive(:origin_last_commit_id)
    allow(code_manager_mock).to receive(:pull)
    allow(code_manager_mock).to receive(:release)
    allow(code_manager_mock).to receive(:find_commit_id)

    allow(branch_mock).to receive(:name).and_return('feature/branch')
    allow(code_manager_mock).to receive(:origin_branches).and_return([branch_mock])

    allow(Genova::CodeManager::Git).to receive(:new).and_return(code_manager_mock)
  end
end

RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end
