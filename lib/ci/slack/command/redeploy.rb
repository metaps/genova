module CI
  module Slack
    module Command
      class Redeploy < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, _match)
            logger.info "Execute redeploy command: (UNAME: #{client.owner}, user=#{data.user})"

            history = CI::Deploy::History.new(data.user).last
            bot = CI::Slack::Bot.new(client.web_client)

            if history.present?
              confirm_deploy(bot, history[:account], history[:repository], history[:branch], history[:environment])
            else
              bot.post_error('History does not exist.', data.user)
            end
          end

          private

          def confirm_deploy(bot, account, repository, branch, environment)
            bot.post_confirm_deploy(account, repository, branch, environment, true)
          end
        end
      end
    end
  end
end
