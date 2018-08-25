require 'rails_helper'

module Genova
  module Docker
    describe Client do
      let(:repository_manager) { Genova::Git::LocalRepositoryManager.new('account', 'repository', 'master') }
      let(:docker_client) { Genova::Docker::Client.new(repository_manager, region: 'region') }

      describe 'build_images' do
        include_context 'load local_repository_manager_mock'

        it 'should be return repository names' do
          containers_config = [
            {
              name: 'app',
              build: '.'
            }
          ]

          allow(File).to receive(:exist?).and_return(true)

          executor_mock = double(Genova::Command::Executor)
          allow(executor_mock).to receive(:command)
          allow(Genova::Command::Executor).to receive(:new).and_return(executor_mock)

          expect(docker_client.build_images(containers_config, 'task_definition_path')).to eq(['app'])
        end
      end
    end
  end
end
