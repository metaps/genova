require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Redeploy do
        let(:bot_mock) { double(Genova::Slack::Bot) }

        context 'when exists history' do
          it 'should be return confirm message' do
            history_mock = double(Genova::Slack::History)
            allow(history_mock).to receive(:last).and_return(
              account: 'account',
              repository: 'repository',
              branch: 'branch',
              cluster: 'cluster',
              service: 'service'
            )
            allow(Genova::Slack::History).to receive(:new).and_return(history_mock)

            allow(bot_mock).to receive(:post_confirm_deploy)
            allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

            command = "#{SlackRubyBot.config.user} redeploy"
            expect(message: command, channel: 'channel').to not_respond
            expect(bot_mock).to have_received(:post_confirm_deploy).once
          end
        end

        context 'when not exist history' do
          it 'should be return error' do
            history_mock = double(Genova::Slack::History)
            allow(history_mock).to receive(:last).and_return(nil)
            allow(Genova::Slack::History).to receive(:new).and_return(history_mock)

            allow(bot_mock).to receive(:post_error)
            allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

            command = "#{SlackRubyBot.config.user} redeploy"
            expect(message: command, channel: 'channel').to not_respond
            expect(bot_mock).to have_received(:post_error).once
          end
        end
      end
    end
  end
end
