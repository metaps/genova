require 'rails_helper'

module Genova
  module Docker
    describe Client do
      describe 'build_image' do
        let(:cipher_mock) { double(EcsDeployer::Util::Cipher) }
        let(:code_manager) { Genova::CodeManager::Git.new('account', 'repository', 'master') }
        let(:docker_client) { Genova::Docker::Client.new(code_manager) }

        include_context 'load code_manager_mock'

        it 'should be return repository name' do
          allow(EcsDeployer::Util::Cipher).to receive(:new).and_return(cipher_mock)

          container_config = {
            name: 'nginx',
            build: '.'
          }

          allow(File).to receive(:exist?).and_return(true)

          executor_mock = double(Genova::Command::Executor)
          allow(executor_mock).to receive(:command)
          allow(Genova::Command::Executor).to receive(:new).and_return(executor_mock)

          expect(docker_client.build_image(container_config, 'test.yml')).to eq('nginx')
        end
      end
    end
  end
end
