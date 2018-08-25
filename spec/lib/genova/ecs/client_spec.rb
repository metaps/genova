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

        ecr_client_mock = double(Genova::Ecr::Client)
        allow(ecr_client_mock).to receive(:push_image)
        allow(ecr_client_mock).to receive(:destroy_images)
        allow(Genova::Ecr::Client).to receive(:new).and_return(ecr_client_mock)

        docker_client_mock = double(Genova::Docker::Client)
        allow(docker_client_mock).to receive(:build_images).and_return(['repository_name'])
        allow(Genova::Docker::Client).to receive(:new).and_return(docker_client_mock)
      end

      describe 'deploy_service' do
        include_context 'load local_repository_manager_mock'

        let(:repository_manager) { Genova::Git::LocalRepositoryManager.new('account', 'repository', 'master') }
        let(:client)  { Genova::Ecs::Client.new('cluster', repository_manager, region: 'region') }

        it 'should be return Aws::ECS::Types::TaskDefinition' do
          expect(client.deploy_service('service', 'tag_revision').to_s).to eq(double(Aws::ECS::Types::TaskDefinition).to_s)
        end
      end
    end
  end
end
