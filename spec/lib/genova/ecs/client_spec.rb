require 'rails_helper'

module Genova
  module Ecs
    describe Client do
      before do
        service_client_mock = double(Ecs::Deployer::Service::Client)
        allow(service_client_mock).to receive(:wait_timeout=)
        allow(service_client_mock).to receive(:update)
        allow(service_client_mock).to receive(:exist?).and_return(true)
        allow(Ecs::Deployer::Service::Client).to receive(:new).and_return(service_client_mock)

        task_definition_mock = double(Aws::ECS::Types::TaskDefinition)
        allow(task_definition_mock).to receive(:task_definition_arn).and_return('task_definition_arn')

        task_client_mock = double(Ecs::Task::Client)
        allow(task_client_mock).to receive(:register).and_return(task_definition_mock)

        ecr_client_mock = double(Ecr::Client)
        allow(ecr_client_mock).to receive(:push_image)
        allow(ecr_client_mock).to receive(:destroy_images)
        allow(Ecr::Client).to receive(:new).and_return(ecr_client_mock)

        allow(Ecs::Task::Client).to receive(:new).and_return(task_client_mock)

        docker_client_mock = double(Genova::Docker::Client)
        allow(docker_client_mock).to receive(:build_image).and_return(['repository_name'])
        allow(Genova::Docker::Client).to receive(:new).and_return(docker_client_mock)
      end

      describe 'deploy_service' do
        include_context 'load code_manager_mock'

        let(:code_manager) { CodeManager::Git.new('account', 'repository', 'master') }
        let(:client)  { Ecs::Client.new('cluster', code_manager) }

        it 'should be return Aws::ECS::Types::TaskDefinition' do
          expect(client.deploy_service('service', 'tag_revision')).to eq('task_definition_arn')
        end
      end
    end
  end
end
