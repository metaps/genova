require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Help do
        let(:slack_web_client) { double(::Slack::Web::Client) }
        let(:slack_messages_message) { double(::Slack::Messages::Message) }
        let(:bot) { double(Genova::Slack::Interactive::Bot) }

        before do
          allow(Genova::Slack::Interactive::Bot).to receive(:new).and_return(bot)
        end

        it 'should return help message' do
          allow(slack_messages_message).to receive_message_chain(:user, :real_name).and_return('bot_user')
          allow(slack_web_client).to receive(:users_info).and_return(slack_messages_message)
          allow(::Slack::Web::Client).to receive(:new).and_return(slack_web_client)

          allow(bot).to receive(:send_message)
          expect { Genova::Slack::Command::Help.call({}, 'user', Time.now.utc.to_f) }.not_to raise_error
        end
      end
    end
  end
end
