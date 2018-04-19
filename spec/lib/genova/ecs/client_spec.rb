require 'rails_helper'

module Genova
  module Ecs
    describe Client do
      before do
        service_client_mock = double(EcsDeployer::Service::Client)
        allow(service_client_mock).to receive(:exist?).and_return(false)
        allow(service_client_mock).to receive(:wait_timeout=)
        allow(service_client_mock).to receive(:update)

        task_definition_mock = double(Aws::ECS::Types::TaskDefinition)
        allow(task_definition_mock).to receive(:task_definition_arn).and_return('task_definition_arn')

        task_client_mock = double(EcsDeployer::Task::Client)
        allow(task_client_mock).to receive(:register).and_return(task_definition_mock)

        ecs_deployer_mock = double(EcsDeployer::Client)
        allow(ecs_deployer_mock).to receive(:service).and_return(service_client_mock)
        allow(ecs_deployer_mock).to receive(:task).and_return(task_client_mock)
        allow(EcsDeployer::Client).to receive(:new).and_return(ecs_deployer_mock)

        deploy_config = Genova::Config::DeployConfig.new(
          clusters: [
            {
              name: 'cluster',
              services: {
                service: {
                  formation: {
                    cluster: 'cluster',
                    service_name: 'service_name',
                    task_definition: 'task_definition',
                    desired_count: 1
                  }
                }
              }
            }
          ]
        )
        local_repository_manager_mock = double(Genova::Git::LocalRepositoryManager)

        allow(local_repository_manager_mock).to receive(:open_deploy_config).and_return(deploy_config)
        allow(local_repository_manager_mock).to receive(:task_definition_config_path)
        allow(Genova::Git::LocalRepositoryManager).to receive(:new).and_return(local_repository_manager_mock)
      end

      describe 'deploy_service' do
        let(:repository_manager) { Genova::Git::LocalRepositoryManager.new('account', 'repository', 'master') }
        let(:client)  { Genova::Ecs::Client.new('cluster', repository_manager, region: 'region') }

        it 'should be return Aws::ECS::Types::TaskDefinition' do
          expect(client.deploy_service('service', 'tag_revision').to_s).to eq(double(Aws::ECS::Types::TaskDefinition).to_s)
        end
      end
    end
  end
end
