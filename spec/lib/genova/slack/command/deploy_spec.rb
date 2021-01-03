require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Deploy do
        let(:bot_mock) { double(Genova::Slack::Bot) }

        context 'when manual deploy' do
          it 'should be return confirm message' do
            allow(bot_mock).to receive(:post_confirm_deploy)
            allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

            statements = {
              command: 'deploy',
              params: {
                repository: 'repository',
                cluster: 'cluster',
                service: 'service'
              }
            }
            expect { Genova::Slack::Command::Deploy.call(bot_mock, statements, 'user') }.not_to raise_error
            expect(bot_mock).to have_received(:post_confirm_deploy).once
          end
        end

        context 'when interactive deploy' do
          it 'should be return repositories' do
            allow(bot_mock).to receive(:post_choose_repository)
            allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

            statements = {
              command: 'deploy',
              params: {}
            }

            expect { Genova::Slack::Command::Deploy.call(bot_mock, statements, 'user') }.not_to raise_error
            expect(bot_mock).to have_received(:post_choose_repository).once
          end
        end
      end
    end
  end
end
