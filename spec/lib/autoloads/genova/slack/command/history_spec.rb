require 'rails_helper'

module Genova
  module Slack
    module Command
      describe History do
        let(:bot) { double(Genova::Slack::Interactive::Bot) }

        include_context :session_start

        before do
          Genova::RedisPool.get.flushdb

          allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)
        end

        context 'when history exists' do
          it 'should sent history to slack' do
            allow(Genova::Slack::BlockKit::ElementObject).to receive(:history_options).and_return([text: 'text', value: 'value'])
            allow(bot).to receive(:ask_history)

            expect { Genova::Slack::Command::History.call({}, 'user', Time.now.utc.to_f) }.not_to raise_error
          end
        end
      end
    end
  end
end
