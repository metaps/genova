require 'rails_helper'

module Genova
  module Slack
    module Command
      describe Help do
        it 'should be return help message' do
          expect(message: "#{SlackRubyBot.config.user} help", channel: 'channel').to respond_with_slack_message(/Hello, I'm ECS deploy Bot\./)
        end
      end
    end
  end
end
