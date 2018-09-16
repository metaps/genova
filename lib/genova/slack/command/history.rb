module Genova
  module Slack
    module Command
      class History < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, match)
            logger.info("Execute history command: (UNAME: #{client.owner}, user=#{data.user})")
            logger.info("Input command: #{match['command']} #{match['expression']}")

            options = Genova::Slack::Util.history_options(data.user)
            bot = Genova::Slack::Bot.new(client.web_client)

            if options.present?
              bot.post_choose_history(options: options)
            else
              e = HistoryError.new('History does not exist.')
              bot.post_error(error: e, slack_user_id: data.user)
            end
          end
        end
      end

      class HistoryError < Error; end
    end
  end
end
