require 'rails_helper'

module Genova
  module Ecs
    module Deployer
      module RunTask
        describe 'Client' do
          let(:deploy_job) do
            DeployJob.create!(
              id: DeployJob.generate_id,
              mode: DeployJob.mode.find_value(:manual),
              type: DeployJob.type.find_value(:service),
              account: Settings.github.account,
              repository: 'repository',
              cluster: 'cluster'
            )
          end
          let(:ecs_client) { double(Aws::ECS::Client) }
          let(:client) { Client.new(deploy_job) }

          before do
            DeployJob.collection.drop
            allow(Settings.ecs).to receive(:wait_timeout).and_return(0.3)
            allow(Settings.ecs).to receive(:polling_interval).and_return(0.1)
          end

          describe 'execute' do
            it 'shuold be not error' do
              allow(ecs_client).to receive(:run_task).and_return(
                tasks: [{
                  task_arn: 'task_arn'
                }]
              )
              allow(ecs_client).to receive(:describe_tasks).and_return({
                                                                         tasks: [
                                                                           task_arn: 'task_arn',
                                                                           last_status: 'STOPPED',
                                                                           containers: []
                                                                         ]
                                                                       })
              allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
              client.execute('task_definition_arn')

              expect(deploy_job.task_definition_arn).to eq('task_definition_arn')
              expect(deploy_job.task_arns).to eq(['task_arn'])
            end
          end
        end
      end
    end
  end
end
