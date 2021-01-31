require 'rails_helper'

module Genova
  module Slack
    module Command
      describe History do
        let(:bot_mock) { double(Genova::Slack::Interactive::Bot) }

        include_context :session_start

        before do
          Redis.current.flushdb

          allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot_mock)
        end

        context 'when history exists' do
          it 'should be sent history to slack' do
            allow(Genova::Slack::BlockKit::ElementObject).to receive(:history_options).and_return([text: 'text', value: 'value'])
            allow(bot_mock).to receive(:ask_history)

            expect { Genova::Slack::Command::History.call(bot_mock, {}, 'user') }.not_to raise_error
          end
        end
      end
    end
  end
end
