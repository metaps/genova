require 'rails_helper'

module Genova
  module Docker
    describe Client do
      describe 'build_image' do
        let(:cipher_mock) { double(Utils::Cipher) }
        let(:code_manager_mock) { double(CodeManager::Git) }
        let(:task_definition_config_mock) do
          Genova::Config::TaskDefinitionConfig.new(
            container_definitions: [{
              name: 'nginx',
              image: 'xxx/nginx:revision_tag'
            }]
          )
        end
        let(:docker_client) { Genova::Docker::Client.new(code_manager_mock) }

        it 'should be return repository name' do
          allow(code_manager_mock).to receive(:base_path).and_return('.')
          allow(code_manager_mock).to receive(:load_task_definition_config).and_return(task_definition_config_mock)
          allow(Utils::Cipher).to receive(:new).and_return(cipher_mock)

          container_config = {
            name: 'nginx',
            build: '.'
          }

          allow(File).to receive(:file?).and_return(true)

          executor_mock = double(Command::Executor)
          allow(executor_mock).to receive(:command)
          allow(Command::Executor).to receive(:new).and_return(executor_mock)

          allow(::Docker::Image).to receive(:all).and_return(foo: 'bar')

          expect(docker_client.build_image(container_config, 'test.yml')).to eq('nginx')
        end
      end
    end
  end
end
