require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Help do
        let(:bot_mock) { double(Genova::Slack::Bot) }

        before do
          allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)
        end

        it 'should be return help message' do
          allow(bot_mock).to receive(:post_simple_message)
          expect { Genova::Slack::Command::Help.call(bot_mock, {}, 'user') }.not_to raise_error
        end
      end
    end
  end
end
