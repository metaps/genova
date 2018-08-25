require 'rails_helper'

module Genova
  describe Client do
    let(:task_definition_mock) { double(Aws::ECS::Types::TaskDefinition) }
    let(:ecs_client_mock) { double(Genova::Ecs::Client) }
    let(:docker_client_mock) { double(Genova::Docker::Client) }

    before do
      allow(task_definition_mock).to receive(:task_definition_arn)
      allow(ecs_client_mock).to receive(:ready)
      allow(ecs_client_mock).to receive(:deploy_service).and_return(task_definition_mock)

      allow(File).to receive(:exist?).with("#{ENV.fetch('HOME')}/.ssh/id_rsa").and_return(true)
      allow(Genova::Ecs::Client).to receive(:new).and_return(ecs_client_mock)
    end

    describe 'run' do
      include_context 'load local_repository_manager_mock'

      it 'shuold be return task definition' do
        client = Genova::Client.new(repository: 'repository', cluster: 'cluster')
        client.run
      end
    end
  end
end
