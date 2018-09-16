module Genova
  module Slack
    module Command
      class Redeploy < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, match)
            logger.info("Execute redeploy command: (UNAME: #{client.owner}, user=#{data.user})")
            logger.info("Input command: #{match['command']} #{match['expression']}")

            history = Genova::Slack::History.new(data.user).last
            bot = Genova::Slack::Bot.new(client.web_client)

            if history.present?
              bot.post_confirm_deploy(
                account: history[:account],
                repository: history[:repository],
                branch: history[:branch],
                cluster: history[:cluster],
                service: history[:service],
                scheduled_task_rule: history[:scheduled_task_rule],
                scheduled_task_target: history[:scheduled_task_target],
                confirm: true
              )
            else
              e = RedeployError.new('History does not exist.')
              bot.post_error(error: e, slack_user_id: data.user)
            end
          end
        end
      end

      class RedeployError < Genova::Error; end
    end
  end
end
