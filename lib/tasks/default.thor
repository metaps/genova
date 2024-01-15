# Stop processing if an error occurs in `config/initializer/validator.rb`.
unless Rails.application.initialized?
  puts 'Rails environment was not loaded correctly.'
  exit(1)
end

require './lib/tasks/deploy'
require './lib/tasks/utils'

module GenovaCli
  class Default < Thor
    namespace :genova

    desc 'deploy', 'Deploy application to Amazon ECS.'
    subcommand 'deploy', ::GenovaCli::Deploy

    desc 'utils', 'Provides useful utilities related to deployment.'
    subcommand 'utils', ::GenovaCli::Utils

    desc 'version', 'Show version.'
    def version
      puts ::Genova::Version::LONG_STRING
    end
  end
end
