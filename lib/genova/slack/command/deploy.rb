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

            split = args[0].split('/')

            if split.size == 2
              results[:account] = split[0]
              results[:repository] = split[1]
            else
              results[:account] = Settings.github.account
              results[:repository] = split[0]
            end

            results[:branch] = args[1]

            split = args[2].split(':')

            raise DeployError, 'Wrong specification of third argument. Please check `help`.' unless split.size == 2

            results[:cluster] = split[0]
            results[:service] = split[1]

            results
          end
        end
      end

      class DeployError < Error; end
    end
  end
end
