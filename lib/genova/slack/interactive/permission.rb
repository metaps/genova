module Genova
  module Slack
    module Interactive
      class Permission
        def initialize(name)
          @name = name
        end

        def allow_clusters(repository, params)
          manager = ::Genova::CodeManager::Git.new(ENV.fetch('GITHUB_ACCOUNT'), repository, params)
          clusters = []

          deploy_config = manager.load_deploy_config
          deploy_config[:clusters].each do |values|
            clusters << values[:name] if check_cluster(values[:name])
          end

          clusters
        end

        def check_cluster(cluster)
          permissions_config = Settings.slack.permissions
          return true if permissions_config.nil?

          matched = permissions_config.find do |permission|
            pos = permission[:cluster].index('*')

            matched = if pos.nil?
                        cluster == permission[:cluster]
                      else
                        cluster.index(permission[:cluster][0, pos]).present?
                      end

            next unless matched

            allow_users = permission[:allow_users] || []
            allow_users.find { |allow_user| @name == allow_user }.present?
          end

          matched.present?
        end
      end
    end
  end
end
