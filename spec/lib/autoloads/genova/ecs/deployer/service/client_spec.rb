require 'rails_helper'

module Genova
  module Ecs
    module Deployer
      describe Service do
        let(:deploy_job) do
          DeployJob.create!(
            id: DeployJob.generate_id,
            mode: DeployJob.mode.find_value(:manual),
            type: DeployJob.type.find_value(:service),
            account: Settings.github.account,
            repository: 'repository',
            cluster: 'cluster',
            service: 'service'
          )
        end
        let(:ecs_client) { double(Aws::ECS::Client) }

        before do
          DeployJob.collection.drop

          allow(Aws::ECS::Client).to receive(:new).and_return(ecs_client)
        end

        describe Client do
          let(:service_client) { Ecs::Deployer::Service::Client.new(deploy_job, ::Logger.new($stdout), async_wait: false) }

          describe 'update' do
            let(:service_provisioning_worker) { double(::Ecs::ServiceProvisioningWorker) }

            it 'should return service arn' do
              update_service_response = double(Aws::ECS::Types::UpdateServiceResponse)
              service = double(Aws::ECS::Types::Service)

              allow(service).to receive(:task_definition)
              allow(update_service_response).to receive(:service).and_return(service)
              allow(ecs_client).to receive(:update_service).and_return(update_service_response)

              allow(service_provisioning_worker).to receive(:perform)
              allow(::Ecs::ServiceProvisioningWorker).to receive(:new).and_return(service_provisioning_worker)

              expect { service_client.update('task_definition_arn') }.to_not raise_error
            end
          end

          describe 'exist?' do
            let(:describe_services_response) { double(Aws::ECS::Types::DescribeServicesResponse) }

            before do
              allow(describe_services_response).to receive(:[]).with(:services).and_return(
                [
                  {
                    service_name: 'service',
                    status: 'ACTIVE'
                  }
                ]
              )
              allow(ecs_client).to receive(:describe_services).and_return(describe_services_response)
            end

            context 'when exist service' do
              it 'should return true' do
                expect(service_client.send(:exist?)).to be(true)
              end
            end
          end
        end
      end
    end
  end
end
