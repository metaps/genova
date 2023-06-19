module Genova
  module Deploy
    module Step
      class Runner
        class << self
          def call(steps, callback, options)
            steps.each.with_index(1) do |step, i|
              callback.start_step(index: i)

              step[:resources].each do |resource|
                service = step[:type] == DeployJob.type.find_value(:service).to_s ? resource : nil
                run_task = step[:type] == DeployJob.type.find_value(:run_task).to_s ? resource : nil
                scheduled_task = step[:type] == DeployJob.type.find_value(:scheduled_task).to_s ? resource : nil

                if scheduled_task.present?
                  parts = scheduled_task.split(':')

                  raise Exceptions::ValidationError, 'For scheduled task, specify the resource name separated by a colon between the rule and target.' unless parts.size == 2

                  scheduled_task_rule, scheduled_task_target = parts
                end

                raise Exceptions::ValidationError, 'Type must be one of `service`, `run_task`, or `scheduled_task`.' if service.nil? && run_task.nil? && scheduled_task.nil?

                deploy_job = DeployJob.create!(
                  id: DeployJob.generate_id,
                  type: DeployJob.type.find_value(step[:type]),
                  status: DeployJob.status.find_value(:initial),
                  mode: options[:mode],
                  slack_user_id: options[:slack_user_id],
                  slack_user_name: options[:slack_user_name],
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
                Deploy::Runner.new(deploy_job, force: options[:force], async_wait: step[:async_wait]).run
                callback.complete_deploy(deploy_job:)
              end
            end

            callback.complete_steps(user: options[:slack_user_id])
          end
        end
      end
    end
  end
end
