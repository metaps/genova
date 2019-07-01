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

            args = expression.split(' ')
            raise InvalidArgumentError, 'Parameter is incorrect.' unless args.size == 3

            results = {
              :mode => :command,
              :account => Settings.github.account,
              :repository => args[0],
              :branch => args[1]
            }

            method_key_value = args[2].split('=')
            raise InvalidArgumentError, 'Target type argument is invalid. Please check `help`.' unless method_key_value.size == 2

            method_key = method_key_value[0]
            method_values = method_key_value[1].split(':')
            method_values_size = {
              :target => 1,
              :service=> 2,
              :'scheduled-task' => 3
            }

            raise InvalidArgumentError, 'Target argument is invalid. Please check `help`.' unless method_values.size == method_values_size[method_key.to_sym]

            case method_key
            when 'target'
                manager = Genova::Git::RepositoryManager.new(results[:account], results[:repository], results[:branch])
                target = manager.load_deploy_config.target(method_values[0])
                results.merge!(target)

            when 'service'
                results[:cluster] = method_values[0]
                results[:service] = method_values[1]

            when 'scheduled-task'
                results[:cluster] = method_values[0]
                results[:scheduled_task_rule] = method_values[1]
                results[:scheduled_task_target] = method_values[2]
            end

            results
          end
        end
      end

      class InvalidArgumentError < Error; end
    end
  end
end
