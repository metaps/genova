require 'rails_helper'

module Genova
  module Slack
    module Command
      describe History do
        let(:bot_mock) { double(Genova::Slack::Bot) }

        before do
          allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)

          Genova::Slack::SessionStore.new('user').clear
        end

        context 'when history exists' do
          it 'should be sent history to slack' do
            allow(Genova::Slack::Util).to receive(:history_options).and_return([text: 'text', value: 'value'])
            allow(bot_mock).to receive(:post_choose_history)

            expect { Genova::Slack::Command::History.call(bot_mock, {}, 'user') }.not_to raise_error
          end
        end
      end
    end
  end
end
