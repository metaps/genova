require 'rails_helper'

module Genova
  module Docker
    describe Client do
      describe 'build_image' do
        let(:cipher_mock) { double(Utils::Cipher) }
        let(:code_manager) { CodeManager::Git.new('account', 'repository', branch: 'master') }
        let(:docker_client) { Genova::Docker::Client.new(code_manager) }

        include_context 'load code_manager_mock'

        it 'should be return repository name' do
          allow(Utils::Cipher).to receive(:new).and_return(cipher_mock)

          container_config = {
            name: 'nginx',
            build: '.'
          }

          allow(File).to receive(:exist?).and_return(true)

          executor_mock = double(Command::Executor)
          allow(executor_mock).to receive(:command)
          allow(Command::Executor).to receive(:new).and_return(executor_mock)

          expect(docker_client.build_image(container_config, 'test.yml')).to eq('nginx')
        end
      end
    end
  end
end
