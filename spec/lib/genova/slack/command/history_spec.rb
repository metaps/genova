require 'rails_helper'

module Genova
  module Slack
    module Command
      describe History do
        let(:bot_mock) { double(Genova::Slack::Bot) }

        before do
          allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)
        end

        context 'when history exists' do
          it 'should be sent history to slack' do
            allow(Genova::Slack::Util).to receive(:history_options).and_return([text: 'text', value: 'value'])
            allow(bot_mock).to receive(:post_choose_history)

            expect { Genova::Slack::Command::History.call(bot_mock, {}, 'user') }.not_to raise_error
            expect(bot_mock).to have_received(:post_choose_history).once
          end
        end

        context 'when history does not exists' do
          it 'should be sent error to slack' do
            allow(Genova::Slack::Util).to receive(:history_options).and_return([])
            allow(bot_mock).to receive(:post_error)

            expect { Genova::Slack::Command::History.call(bot_mock, {}, 'user') }.not_to raise_error
            expect(bot_mock).to have_received(:post_error).once
          end
        end
      end
    end
  end
end
