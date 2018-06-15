require 'rails_helper'

module Genova
  describe Client do
    let(:ecr_client_mock) { double(Genova::Ecr::Client) }
    let(:ecs_client_mock) { double(Genova::Ecs::Client) }
    let(:docker_client_mock) { double(Genova::Docker::Client) }

    before do
      allow(File).to receive(:exist?).with("#{ENV.fetch('HOME')}/.ssh/id_rsa").and_return(true)

      allow(ecr_client_mock).to receive(:authenticate)
      allow(ecr_client_mock).to receive(:push_image)
      allow(ecr_client_mock).to receive(:cleanup_image)
      allow(Genova::Ecr::Client).to receive(:new).and_return(ecr_client_mock)

      allow(docker_client_mock).to receive(:build_images).and_return(['repository_name'])
      allow(Genova::Docker::Client).to receive(:new).and_return(docker_client_mock)

      task_definition_mock = double(Aws::ECS::Types::TaskDefinition)
      allow(task_definition_mock).to receive(:task_definition_arn).and_return('task_definition_arn')

      allow(ecs_client_mock).to receive(:deploy_service).and_return(task_definition_mock)
      allow(Genova::Ecs::Client).to receive(:new).and_return(ecs_client_mock)
    end

    describe 'deploy' do
      include_context 'load local_repository_manager_mock'

      it 'shuold be return task definition' do
        client = Genova::Client.new(repository: 'repository', cluster: 'cluster')
        client.deploy('service')
      end
    end
  end
end
