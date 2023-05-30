module Genova
  module Sidekiq
    module SlackAlert
      def send_error(error, parent_message_ts = nil, user = nil)
        bot = ::Genova::Slack::Interactive::Bot.new(parent_message_ts:)
        bot.error(error:, user:)
      end
    end
  end
end
