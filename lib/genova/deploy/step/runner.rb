module Genova
  module Deploy
    module Step
      class Runner
        class << self
          def call(steps, params, callback)
            steps.each.with_index(1) do |step, i|
              callback.start_step(index: i)

              step[:resources].each do |resource|
                service = step[:type] == DeployJob.type.find_value(:service).to_s ? resource : nil
                run_task = step[:type] == DeployJob.type.find_value(:run_task).to_s ? resource : nil

                deploy_job = DeployJob.create!(
                  id: DeployJob.generate_id,
                  type: DeployJob.type.find_value(step[:type]),
                  status: DeployJob.status.find_value(:in_progress),
                  mode: params[:mode],
                  slack_user_id: params[:slack_user_id],
                  slack_user_name: params[:slack_user_name],
                  account: Settings.github.account,
                  repository: params[:repository] || step[:repository],
                  branch: params[:branch] || step[:branch],
                  cluster: step[:cluster],
                  service: service,
                  scheduled_task_rule: nil,
                  scheduled_task_target: nil,
                  run_task: run_task
                )

                callback.start_deploy(deploy_job: deploy_job)
                Genova::Deploy::Runner.call(deploy_job)
                callback.complete_deploy(deploy_job: deploy_job)
              end
            end

            callback.complete_steps
          end
        end
      end
    end
  end
end
