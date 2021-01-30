module Genova
  module Slack
    module Interactive
      class Permission
        def initialize(user_name)
          @user_name = user_name
        end

        def allow_repository?(repository)
          match?('repository', repository)
        end

        def allow_cluster?(cluster)
          match?('cluster', cluster)
        end

        private

        def match?(policy, user_name)
          permissions = Settings.slack.permissions
          return true if permissions.nil?

          result = permissions.find do |permission|
            next if permission[:policy] != policy

            matched = false
            resources = permission[:resources] || []
            resources.each do |resource|
              pos = resource.index('*')

              matched = if pos.nil?
                          user_name == resource
                        else
                          user_name.index(resource[0, pos]).present?
                        end

              break if matched
            end

            next unless matched

            allow_users = permission[:allow_users] || []
            allow_users.find { |allow_user| @user_name == allow_user }.present?
          end

          result.present?
        end
      end
    end
  end
end
