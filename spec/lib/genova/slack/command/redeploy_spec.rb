require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Redeploy do
        let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

        before do
          Redis.current.flushdb
        end

        context 'when exists history' do
          it 'should be return confirm message' do
            history_mock = double(Genova::Slack::Interactive::History)
            allow(history_mock).to receive(:last).and_return(
              account: 'account',
              repository: 'repository',
              branch: 'branch',
              cluster: 'cluster',
              service: 'service'
            )
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history_mock)

            allow(bot_mock).to receive(:ask_confirm_deploy)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

            expect { Genova::Slack::Command::Redeploy.call(bot_mock, {}, 'user') }.not_to raise_error
            expect(bot_mock).to have_received(:ask_confirm_deploy).once
          end
        end

        context 'when not exist history' do
          it 'should be return error' do
            history_mock = double(Genova::Slack::Interactive::History)
            allow(history_mock).to receive(:last).and_return(nil)
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history_mock)

            allow(bot_mock).to receive(:error)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)

            expect { Genova::Slack::Command::Redeploy.call(bot_mock, {}, 'user') }.not_to raise_error
            expect(bot_mock).to have_received(:error).once
          end
        end
      end
    end
  end
end
