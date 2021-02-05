module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        class Client
          def initialize(cluster, logger)
            @cluster = cluster
            @logger = logger
            @cloud_watch_events = Aws::CloudWatchEvents::Client.new
          end

          def exist_rule?(rule)
            @cloud_watch_events.describe_rule(name: rule)
            true
          rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException
            false
          end

          def update(name, schedule_expression, target, options = {})
            response = @cloud_watch_events.put_rule(
              name: name,
              schedule_expression: schedule_expression,
              state: options[:enabled].nil? || options[:enabled] ? 'ENABLED' : 'DISABLED',
              description: options[:description]
            )
            @logger.info('CloudWatch Events rule has been updated.')
            @logger.info(JSON.pretty_generate(response.to_h))

            response = @cloud_watch_events.put_targets(
              rule: name,
              targets: [target]
            )
            @logger.info('CloudWatch Events target has been updated.')
            @logger.info(JSON.pretty_generate(response.to_h))
          end
        end
      end
    end
  end
end
