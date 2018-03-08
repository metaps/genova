module CI
  module Slack
    module Command
      class History < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, _match)
            logger.info "Execute history command: (UNAME: #{client.owner}, user=#{data.user})"

            options = CI::Slack::Util.history_options(data.user)
            bot = CI::Slack::Bot.new(client.web_client)

            if !options.empty?
              bot.post_choose_history(options)
            else
              bot.post_error('History does not exist.', data.user)
            end
          end
        end
      end
    end
  end
end
