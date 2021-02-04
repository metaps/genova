module Genova
  module Slack
    module Interactive
      class Permission
        def initialize(user_name)
          @user_name = user_name
        end

        def allow_repository?(repository)
          allow?('repository', repository)
        end

        def allow_cluster?(cluster)
          allow?('cluster', cluster)
        end

        private

        def allow?(policy, value)
          permissions = Settings.slack.permissions
          return true if permissions.nil?

          match = permissions.find do |permission|
            next if permission[:policy] != policy
            next unless match?(permission[:resources], value)
            next unless match?(permission[:allow_users], @user_name)

            true
          end

          match.present?
        end

        def match?(values, search)
          return false if values.nil?

          matched = false

          values.each do |value|
            pos = value.index('*')

            matched = if pos.nil?
                        search == value
                      else
                        search.index(value[0, pos]).present?
                      end

            break if matched
          end

          matched
        end
      end
    end
  end
end
