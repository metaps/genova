module Genova
  module Deploy
    module Step
      class Runner
        class << self
          def call(steps, callback, options)
            steps.each.with_index(1) do |step, i|
              callback.start_step(index: i)

              step[:resources].each do |resource|
                service, run_task, scheduled_task = extract_resources(step[:type], resource)
                scheduled_task_rule, scheduled_task_target = extract_scheduled_task(scheduled_task) if scheduled_task.present?

                deploy_job = DeployJob.create!(
                  id: DeployJob.generate_id,
                  type: DeployJob.type.find_value(step[:type]),
                  status: DeployJob.status.find_value(:initial),
                  mode: options[:mode],
                  slack_user_id: options[:slack_user_id],
                  slack_user_name: options[:slack_user_name],
                  slack_timestamp: options[:slack_timestamp],
                  account: Settings.github.account,
                  repository: options[:repository] || step[:repository],
                  branch: options[:branch] || step[:branch],
                  cluster: step[:cluster],
                  service:,
                  scheduled_task_rule:,
                  scheduled_task_target:,
                  run_task:
                )

                callback.start_deploy(deploy_job:)

                bot = Slack::Interactive::Bot.new(parent_message_ts: options[:slack_timestamp])
                canceller = bot.show_stop_button(deploy_job.id).ts

                Deploy::Runner.new(deploy_job, force: options[:force], async_wait: step[:async_wait]).run

                bot.delete_message(canceller)
                callback.complete_deploy(deploy_job:)
              end
            end

            callback.complete_steps(user: options[:slack_user_id])
          end

          def extract_resources(type, resource)
            results = [
              type == DeployJob.type.find_value(:service).to_s ? resource : nil,
              type == DeployJob.type.find_value(:run_task).to_s ? resource : nil,
              type == DeployJob.type.find_value(:scheduled_task).to_s ? resource : nil
            ]
            raise Exceptions::ValidationError, 'Type must be one of `service`, `run_task`, or `scheduled_task`.' if results.all?(&:nil?)

            results
          end

          def extract_scheduled_task(scheduled_task)
            parts = scheduled_task.split(':')
            raise Exceptions::ValidationError, 'For scheduled task, specify the resource name separated by a colon between the rule and target.' unless parts.size == 2

            parts
          end
        end
      end
    end
  end
end
