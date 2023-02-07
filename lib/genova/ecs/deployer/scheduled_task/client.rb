module Genova
  module Ecs
    module Deployer
      module ScheduledTask
        class Client
          def initialize(deploy_job, options = {})
            @deploy_job = deploy_job
            @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
            @eventbridge = Aws::EventBridge::Client.new
          end

          def exist_rule?(rule)
            @eventbridge.list_rules(name_prefix: rule)[:rules].size.positive?
          end

          def exist_target?(rule, target)
            targets = @eventbridge.list_targets_by_rule(rule: rule)
            target = targets.targets.find { |v| v.id == target }
            target.present?
          end

          def update(name, schedule_expression, target, options = {})
            @logger.info('Update Scheduled task settings.')

            raise Exceptions::NotFoundError, "Scheduled task rule does not exist. [#{name}]" unless exist_rule?(name)
            raise Exceptions::NotFoundError, "Scheduled task target does not exist. [#{target[:id]}]" unless exist_target?(name, target[:id])

            @eventbridge.put_rule(
              name: name,
              schedule_expression: schedule_expression,
              state: options[:enabled].nil? || options[:enabled] ? 'ENABLED' : 'DISABLED',
              description: options[:description]
            )
            @logger.info('EventBridge rule has been updated.')

            @eventbridge.put_targets(
              rule: name,
              targets: [target]
            )
            @logger.info('EventBridge target has been updated.')

            @deploy_job.update_status_complate
            Genova::Deploy::Runner.finished(@deploy_job, @logger)
          end
        end
      end
    end
  end
end
