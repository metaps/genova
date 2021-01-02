module Genova
  module Slack
    module Command
      class Deploy
        def self.call(client, command, sub_commands, deploy, logger)
          #logger.info("Execute deploy command: (UNAME: #{client.owner}, user=#{data.user})")
          #logger.info("Input command: #{match['command']} #{match['expression']}")

          begin
            type = case command.split(':')[1]
                   when 'run-task'
                     DeployJob.type.find_value(:run_task)
                   when 'scheduled-task'
                     DeployJob.type.find_value(:scheduled_task)
                   else
                     DeployJob.type.find_value(:service)
                   end

            if sub_commands.size.zero?
              client.post_choose_repository
            else
              expressions = match['expression'].split(' ')
              results = send("parse_#{type}", expressions)

              params = {
                type: type,
                account: results[:account],
                repository: results[:repository],
                branch: results[:branch],
                cluster: results[:cluster],
                run_task: results[:run_task],
                service: results[:service],
                scheduled_task_rule: results[:scheduled_task_rule],
                scheduled_task_target: results[:scheduled_task_target],
                confirm: true
              }

              repository_settings = Genova::Config::SettingsHelper.find_repository!(results[:repository])
              params[:base_path] = repository_settings[:base_path]

              client.post_confirm_deploy(params)
            end
          rescue => e
            logger.error(e)

            client.post_error(
              error: e,
              slack_user_id: data.user
            )
          end
        end

        class << self
          private

          def parse_run_task(expressions)
            validations = {
              account: String,
              repository: String,
              branch: String,
              cluster: String,
              run_task: String
            }

            parse_expressions(expressions, validations)
          end

          def parse_service(expressions)
            validations = {
              account: String,
              repository: String,
              branch: String,
              cluster: String,
              service: String
            }

            parse_expressions(expressions, validations)
          end

          def parse_scheduled_task(expressions)
            validations = {
              account: String,
              repository: String,
              branch: String,
              cluster: String,
              scheduled_task_rule: String,
              scheduled_task_target: String
            }

            parse_expressions(expressions, validations)
          end

          def validate!(values, validations)
            validator = HashValidator.validate(values, validations)
            raise Exceptions::InvalidArgumentError, "#{validator.errors.keys[0]}: #{validator.errors.values[0]}" unless validator.valid?
          end

          def parse_expressions(expressions, validations)
            values = expressions[0].split(':')
            results = {
              account: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account),
              repository: values[0],
              branch: values[1] || Settings.github.default_branch
            }

            expressions[1..-1].each do |expression|
              values = expression.split('=')
              results[values[0].tr('-', '_').to_sym] = values[1]
            end

            if results.include?(:target)
              code_manager = Genova::CodeManager::Git.new(results[:account], results[:repository], branch: results[:branch])
              target = code_manager.load_deploy_config.target(results[:target])

              results.merge!(target)
              results.delete(results[:target])
            end

            validate!(results, validations)

            results
          end
        end
      end
    end
  end
end
