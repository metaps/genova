require 'rails_helper'

module Genova
  module Docker
    describe Client do
      describe 'build_image' do
        let(:cipher) { double(Utils::Cipher) }
        let(:code_manager) { double(CodeManager::Git) }
        let(:docker_client) { Genova::Docker::Client.new(code_manager, ::Logger.new($stdout)) }
        let(:executor) { double(Command::Executor) }

        before do
          allow(code_manager).to receive(:base_path).and_return('.')
          allow(Utils::Cipher).to receive(:new).and_return(cipher)

          allow(File).to receive(:file?).and_return(true)
          allow(Command::Executor).to receive(:call).and_return(0)
          allow(::Docker::Image).to receive(:all).and_return(foo: 'bar')
        end

        context 'when build is string' do
          container_config = {
            name: 'web',
            build: '.'
          }

          it 'should return docker build time' do
            expect(docker_client.build_image(container_config, 'web')).to eq(0.0)
          end

          it 'should return docker build time when --no-cache is specified' do
            docker_client.no_cache = true
            docker_client.build_image(container_config, 'web')

            expect(Genova::Command::Executor).to have_received(:call) do |command, _, _|
              expect(command).to include('--no-cache')
            end
          end
        end

        context 'when build is hash' do
          it 'should return repository name' do
            container_config = {
              name: 'web',
              build: {
                context: '.',
                args: {
                  FOO: 'foo',
                  BAR: 'bar'
                }
              }
            }

            allow(cipher).to receive(:encrypt_format?).and_return(true, false)
            allow(cipher).to receive(:decrypt).and_return('foo', 'bar')

            expect(docker_client.build_image(container_config, 'account_id.dkr.ecr.ap-northeast-1.amazonaws.com/web:latest')).to eq(0.0)
          end
        end
      end
    end
  end
end
