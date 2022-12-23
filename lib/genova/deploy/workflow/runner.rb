module Genova
  module Deploy
    module Workflow
      class Runner
        class << self
          def call(name, callback)
            workflows = Settings.workflows || []
            workflow = workflows.find { |k| k[:name].include?(name) }
            raise Exceptions::ValidationError, "Workflow '#{name}' is undefined." if workflow.nil?

            workflow[:steps].each.with_index(1) do |step, i|
              callback.start_step(index: i)

              step[:resources].each do |resource|
                service = step[:type] == DeployJob.type.find_value(:service).to_s ? resource : nil
                run_task = step[:type] == DeployJob.type.find_value(:run_task).to_s ? resource : nil

                deploy_job = DeployJob.create(
                  id: DeployJob.generate_id,
                  type: DeployJob.type.find_value(step[:type]),
                  status: DeployJob.status.find_value(:in_progress),
                  mode: DeployJob.mode.find_value(:manual),
                  account: Settings.github.account,
                  repository: step[:repository],
                  branch: step[:branch],
                  cluster: step[:cluster],
                  service: service,
                  scheduled_task_rule: nil,
                  scheduled_task_target: nil,
                  run_task: run_task
                )

                params = {
                  deploy_job: deploy_job
                }

                callback.start_deploy(params)
                Genova::Deploy::Runner.call(deploy_job)
                callback.finished_deploy(params)
              end
            end

            callback.finished_all_deploy
          end
        end
      end
    end
  end
end
