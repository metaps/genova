module Genova
  module Slack
    module Interactive
      class Permission
        def initialize(user)
          @user = user
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

          rules = permissions.select { |permission| permission[:policy] == policy }
          return true if rules.size.zero?

          match = rules.find do |rule|
            next unless match?(rule[:resources], value)
            next unless match?(rule[:allow_users], @user)

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
