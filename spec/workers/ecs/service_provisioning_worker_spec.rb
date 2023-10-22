require 'rails_helper'

module Ecs
  describe ServiceProvisioningWorker do
    describe 'perform' do
      let(:deploy_job) do
        DeployJob.create!(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual),
          type: DeployJob.type.find_value(:service),
          account: Settings.github.account,
          repository: 'repository',
          cluster: 'cluster',
          service: 'service',
          task_definition_arn: 'new_task_definition_arn'
        )
      end
      let(:current_task) { double(Aws::ECS::Types::Task) }
      let(:new_task) { double(Aws::ECS::Types::Task) }
      let(:ecs) { double(Aws::ECS::Client) }

      before do
        DeployJob.collection.drop

        allow(Settings.ecs).to receive(:wait_timeout).and_return(0.3)
        allow(Settings.ecs).to receive(:polling_interval).and_return(0.1)

        allow(ecs).to receive(:describe_services).and_return(
          services: [
            desired_count: 1
          ]
        )

        allow(ecs).to receive(:list_tasks).and_return(task_arns: ['current_task_definition_arn'])
        allow(ecs).to receive(:describe_tasks).and_return(
          {
            tasks: [
              {
                task_definition_arn: 'current_task_definition_arn',
                last_status: 'RUNNING'
              }
            ]
          },
          {
            tasks: [
              {
                task_definition_arn: 'new_task_definition_arn',
                last_status: 'RUNNING'
              }
            ]
          }
        )
        allow(Aws::ECS::Client).to receive(:new).and_return(ecs)

        subject.perform(deploy_job.id)
      end

      it 'should in queue' do
        is_expected.to be_processed_in(:ecs_service_provisioning)
      end

      it 'should no retry' do
        is_expected.to be_retryable(false)
      end
    end
  end
end
