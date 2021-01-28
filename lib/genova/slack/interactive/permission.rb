module Genova
  module Slack
    module Interactive
      class Permission
        def initialize(name)
          @name = name
        end

        def allow_repositories(repository)
          allows = []

          Genova::Config::SettingsHelper.repositories.each do |value|
            check_repository(repository)
          end

          allows
        end

        def allow_clusters(repository, params)
          manager = ::Genova::CodeManager::Git.new(ENV.fetch('GITHUB_ACCOUNT'), repository, params)
          allows = []

          deploy_config = manager.load_deploy_config
          deploy_config[:clusters].each do |cluster|
            allows << cluster[:name] if check_cluster(cluster[:name])
          end

          allows
        end

        def check_cluster(cluster)
          permissions = Settings.slack.permissions
          return true if permissions.nil?

          result = permissions.find do |permission|
            next if permission[:policy] != 'cluster'

            matched = false
            resources = permission[:resources] || []
            resources.each do |resource|
              pos = resource.index('*')

              matched = if pos.nil?
                          cluster == resource
                        else
                          cluster.index(resource[0, pos]).present?
                        end

              break if matched
            end

            next unless matched

            allow_users = permission[:allow_users] || []
            allow_users.find { |allow_user| @name == allow_user }.present?
          end

          result.present?
        end
      end
    end
  end
end
