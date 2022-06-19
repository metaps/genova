require 'rails_helper'

module Genova
  module Ecs
    describe Client do
      describe 'deploy_service' do
        let(:client) { Ecs::Client.new('cluster', code_manager_mock) }
        let(:deploy_config_mock) { double(Genova::Config::DeployConfig) }
        let(:task_definition_mock) { double(Aws::ECS::Types::TaskDefinition) }
        let(:code_manager_mock) { double(CodeManager::Git) }
        let(:ecr_client_mock) { double(Ecr::Client) }
        let(:docker_client_mock) { double(Genova::Docker::Client) }
        let(:service_client_mock) { double(Ecs::Deployer::Service::Client) }

        it 'should be return DeployResponse' do
          allow(code_manager_mock).to receive(:load_deploy_config).and_return(deploy_config_mock)
          allow(code_manager_mock).to receive(:task_definition_config_path).and_return('task_definition_path')

          allow(ecr_client_mock).to receive(:push_image)
          allow(Ecr::Client).to receive(:new).and_return(ecr_client_mock)

          allow(deploy_config_mock).to receive(:find_service).and_return(
            containers: [
              name: 'web'
            ]
          )
          allow(deploy_config_mock).to receive(:find_cluster).and_return([])

          allow(task_definition_mock).to receive(:[]).with(:container_definitions).and_return(
            [{
              name: 'web'
            }]
          )
          allow(task_definition_mock).to receive(:task_definition_arn).and_return('task_definition_arn')

          allow(docker_client_mock).to receive(:build_image).and_return(['repository_name'])
          allow(Genova::Docker::Client).to receive(:new).and_return(docker_client_mock)

          task_client_mock = double(Ecs::Task::Client)
          allow(task_client_mock).to receive(:register).and_return(task_definition_mock)
          allow(Ecs::Task::Client).to receive(:new).and_return(task_client_mock)

          allow(service_client_mock).to receive(:update)
          allow(service_client_mock).to receive(:exist?).and_return(true)
          allow(Ecs::Deployer::Service::Client).to receive(:new).and_return(service_client_mock)

          expect(client.deploy_service('service', 'tag')).to be_a(DeployResponse)
        end
      end
    end
  end
end
