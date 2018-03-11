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
              confirm_deploy(bot, history[:account], history[:repository], history[:branch], history[:service])
            else
              bot.post_error('History does not exist.', data.user)
            end
          end

          private

          def confirm_deploy(bot, account, repository, branch, service)
            bot.post_confirm_deploy(account, repository, branch, service, true)
          end
        end
      end
    end
  end
end
