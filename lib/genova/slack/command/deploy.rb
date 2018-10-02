module Genova
  module Slack
    module Command
      class Deploy < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, match)
            logger.info("Execute deploy command: (UNAME: #{client.owner}, user=#{data.user})")
            logger.info("Input command: #{match['command']} #{match['expression']}")

            bot = Genova::Slack::Bot.new(client.web_client)

            begin
              results = parse_args(match['expression'])

              if results[:mode] == :command
                bot.post_confirm_deploy(
                  account: results[:account],
                  repository: results[:repository],
                  branch: results[:branch],
                  cluster: results[:cluster],
                  service: results[:service],
                  scheduled_task_rule: results[:scheduled_task_rule],
                  scheduled_task_target: results[:scheduled_task_target],
                  confirm: true
                )
              else
                bot.post_choose_repository
              end
            rescue => e
              logger.error(e)

              bot.post_error(
                error: e,
                slack_user_id: data.user
              )
            end
          end

          private

          def parse_args(expression)
            return { mode: :interactive } if expression.blank?

            results = {
              mode: :command
            }

            args = expression.split(' ')
            raise DeployError, 'Parameter is incorrect.' unless args.size == 3

            results[:account] = Settings.github.account
            results[:repository] = args[0]
            results[:branch] = args[1]

            target = args[2].split('=')
            raise DeployError, 'Target type argument is invalid. Please check `help`.' unless target.size == 2

            split = target[1].split(':')
            valid_args = target[0] == 'service' ? 2 : 3

            raise DeployError, 'Target argument is invalid. Please check `help`.' unless split.size == valid_args

            results[:cluster] = split[0]

            if target[0] == 'service'
              results[:service] = split[1]
            else
              results[:scheduled_task_rule] = split[1]
              results[:scheduled_task_target] = split[2]
            end

            results
          end
        end
      end

      class DeployError < Error; end
    end
  end
end
