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
          it 'should be return confirm message' do
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

        context 'when interactive deploy' do
          it 'should be return repositories' do
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
