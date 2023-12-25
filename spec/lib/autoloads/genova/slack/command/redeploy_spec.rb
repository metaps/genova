require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Redeploy do
        let(:bot) { double(Genova::Slack::Interactive::Bot) }

        include_context :session_start

        context 'when exists history' do
          it 'should return confirm message' do
            history = double(Genova::Slack::Interactive::History)
            allow(history).to receive(:last).and_return(
              account: 'account',
              repository: 'repository',
              branch: 'branch',
              cluster: 'cluster',
              service: 'service'
            )
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history)

            allow(bot).to receive(:ask_confirm_deploy)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

            expect { Genova::Slack::Command::Redeploy.call({}, 'user', Time.now.utc.to_f) }.not_to raise_error
            expect(bot).to have_received(:ask_confirm_deploy).once
          end
        end

        context 'when not exist history' do
          it 'should return error' do
            history = double(Genova::Slack::Interactive::History)
            allow(history).to receive(:last).and_return(nil)
            allow(Genova::Slack::Interactive::History).to receive(:new).and_return(history)

            allow(bot).to receive(:error)
            allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)

            expect { Genova::Slack::Command::Redeploy.call(bot, {}, 'user') }.to raise_error(Exceptions::NotFoundError)
          end
        end
      end
    end
  end
end
