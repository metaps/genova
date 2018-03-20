module Genova
  module Slack
    module Command
      class History < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, _match)
            logger.info "Execute history command: (UNAME: #{client.owner}, user=#{data.user})"

            options = Genova::Slack::Util.history_options(data.user)
            bot = Genova::Slack::Bot.new(client.web_client)

            if !options.empty?
              bot.post_choose_history(options: options)
            else
              bot.post_error(message: 'History does not exist.', slack_user_id: data.user)
            end
          end
        end
      end
    end
  end
end
