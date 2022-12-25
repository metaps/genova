require 'rails_helper'

module Genova
  module Ecs
    describe Client do
      describe 'deploy_service' do
        before do
          DeployJob.collection.drop
        end

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
        let(:code_manager) { double(CodeManager::Git) }
        let(:client) { Ecs::Client.new(deploy_job, code_manager) }
        let(:deploy_config) { double(Genova::Config::DeployConfig) }
        let(:task_definition) { double(Aws::ECS::Types::TaskDefinition) }
        let(:ecr_client) { double(Ecr::Client) }
        let(:docker_client) { double(Genova::Docker::Client) }
        let(:service_client) { double(Ecs::Deployer::Service::Client) }

        it 'shuold be not error' do
          allow(code_manager).to receive(:load_deploy_config).and_return(deploy_config)
          allow(code_manager).to receive(:task_definition_config_path).and_return('task_definition_path')

          allow(ecr_client).to receive(:push_image)
          allow(Ecr::Client).to receive(:new).and_return(ecr_client)

          allow(deploy_config).to receive(:find_service).and_return(
            containers: [
              name: 'web'
            ]
          )
          allow(deploy_config).to receive(:find_cluster).and_return([])

          allow(task_definition).to receive(:[]).with(:container_definitions).and_return(
            [{
              name: 'web'
            }]
          )
          allow(task_definition).to receive(:task_definition_arn).and_return('task_definition_arn')

          allow(docker_client).to receive(:build_image).and_return(['repository_name'])
          allow(Genova::Docker::Client).to receive(:new).and_return(docker_client)

          task_client = double(Ecs::Task::Client)
          allow(task_client).to receive(:register).and_return(task_definition)
          allow(Ecs::Task::Client).to receive(:new).and_return(task_client)

          allow(service_client).to receive(:update)
          allow(service_client).to receive(:exist?).and_return(true)
          allow(Ecs::Deployer::Service::Client).to receive(:new).and_return(service_client)

          expect { client.deploy_service(async_wait: false) }.to_not raise_error
        end
      end
    end
  end
end
