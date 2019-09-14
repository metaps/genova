module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        class Client
          def initialize(cluster)
            @cluster = cluster
            @cloud_watch_events = Aws::CloudWatchEvents::Client.new
          end

          def exist_rule?(rule)
            @cloud_watch_events.describe_rule(name: rule)
            true
          rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException
            false
          end

          def update(rule, schedule_expression, targets = [], options = { description: nil })
            response = @cloud_watch_events.put_rule(
              name: rule,
              schedule_expression: schedule_expression,
              state: 'ENABLED',
              description: options[:description]
            )
            @cloud_watch_events.put_targets(
              rule: rule,
              targets: targets
            )

            response
          end
        end
      end
    end
  end
end
