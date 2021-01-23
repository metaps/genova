module Genova
  module Slack
    class Permission
      def initialize(username)
        @username = username
      end

      def allow_clusters(repository, params)
        manager = ::Genova::CodeManager::Git.new(ENV.fetch('GITHUB_ACCOUNT'), repository, params)
         clusters = []

         deploy_config = manager.load_deploy_config
         deploy_config[:clusters].each do |values|
           clusters << values[:name] if check_deploy(values[:name])
         end

         clusters
      end

      def check_deploy(cluster)
        permission = Settings.slack.permission.deploy
        return true if permission.nil?

        matched = false

        permission.each do |params|
          pos = params[:cluster].index('*')

          if pos.present?
            next unless cluster.index(params[:cluster][0, pos])
          else
            next unless cluster == params[:cluster]
          end

          allow_users = params[:allow_users] || []
          allow_users.each do |allow_user|
            if @username == allow_user
              matched = true
              break
            end
          end

          break if matched
        end

        matched
      end
    end
  end
end
