require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Deploy do
        let(:bot) { double(Genova::Slack::Interactive::Bot) }

        include_context :session_start

        before do
          Genova::RedisPool.get.flushdb
        end

        context 'when manual deploy' do
          it 'should return confirm message' do
            allow(bot).to receive(:ask_confirm_deploy)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

            statements = {
              command: 'deploy',
              params: {
                repository: 'repository',
                cluster: 'cluster',
                service: 'service'
              }
            }
            expect { Genova::Slack::Command::Deploy.call(statements, 'user', Time.now.utc.to_f) }.not_to raise_error
          end
        end

        context 'when repository name is invalid' do
          it 'should raise error' do
            allow(bot).to receive(:ask_confirm_deploy)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)
            allow(FileUtils).to receive(:rm_rf)
            allow(::Git).to receive(:open)

            statements = {
              command: 'deploy',
              params: {
                repository: '../../..',
                branch: 'master',
                cluster: 'cluster',
                service: 'service',
                target: 'target'
              }
            }

            expect { Genova::Slack::Command::Deploy.call(statements, 'user', Time.now.utc.to_f) }.to raise_error(Genova::Exceptions::InvalidArgumentError)
            expect(FileUtils).not_to have_received(:rm_rf)
            expect(::Git).not_to have_received(:open)
            expect(bot).not_to have_received(:ask_confirm_deploy)
          end
        end

        context 'when interactive deploy' do
          it 'should return repositories' do
            allow(bot).to receive(:ask_repository)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

            statements = {
              command: 'deploy',
              params: {}
            }

            expect { Genova::Slack::Command::Deploy.call(statements, 'user', Time.now.utc.to_f) }.not_to raise_error
          end
        end
      end
    end
  end
end
