module Genova
  module Slack
    module Command
      class Redeploy < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, _match)
            logger.info "Execute redeploy command: (UNAME: #{client.owner}, user=#{data.user})"

            history = Genova::Deploy::History.new(data.user).last
            bot = Genova::Slack::Bot.new(client.web_client)

            if history.present?
              bot.post_confirm_deploy(
                account: history[:account],
                repository: history[:repository],
                branch: history[:branch],
                cluster: history[:cluster],
                service: history[:service]
              )
            else
              bot.post_error(message: 'History does not exist.', slack_user_id: data.user)
            end
          end
        end
      end
    end
  end
end
