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
            raise InvalidArgumentError, 'Parameter is incorrect.' unless args.size == 3

            results[:account] = Settings.github.account
            results[:repository] = args[0]
            results[:branch] = args[1]

            method = args[2].split('=')
            raise InvalidArgumentError, 'Target type argument is invalid. Please check `help`.' unless method.size == 2

            method_values = method[1].split(':')
            method_arg_sizes = {
              :target => 1,
              :service=> 2,
              :'scheduled-task' => 3
            }

            method_arg_size = method_arg_sizes[method[0].to_sym]

            raise InvalidArgumentError, 'Target argument is invalid. Please check `help`.' unless method_values.size == method_arg_size

            if method[0] == 'target'
              manager = Genova::Git::RepositoryManager.new(results[:account], results[:repository], results[:branch])
              target = manager.load_deploy_config.target(method_values[0])
              results.merge!(target)

            elsif method[0] == 'service'
              results[:cluster] = method_values[0]
              results[:service] = method_values[1]
            else
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
