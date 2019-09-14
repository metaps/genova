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

          def update(name, schedule_expression, targets = [], options = {})
            response = @cloud_watch_events.put_rule(
              name: name,
              schedule_expression: schedule_expression,
              state: options[:enabled].nil? || options[:enabled] ? 'ENABLED' : 'DISABLED',
              description: options[:description]
            )
            @cloud_watch_events.put_targets(
              rule: name,
              targets: targets
            )

            response
          end
        end
      end
    end
  end
end
