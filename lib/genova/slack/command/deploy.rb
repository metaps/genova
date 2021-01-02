module Genova
  module Slack
    module Command
      class Deploy
        def self.call(client, statements, user)
          type = case statements[:sub_command]
                 when 'run-task'
                   DeployJob.type.find_value(:run_task)
                 when 'scheduled-task'
                   DeployJob.type.find_value(:scheduled_task)
                 else
                   DeployJob.type.find_value(:service)
                 end

          if statements[:params].size.zero?
            client.post_choose_repository
          else
            results = send("parse_#{type}", statements[:params])

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

            params[:base_path] = Genova::Config::SettingsHelper.find_repository!(results[:repository])
            client.post_confirm_deploy(params)
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
            raise Genova::Exceptions::InvalidArgumentError, "#{validator.errors.keys[0]}: #{validator.errors.values[0]}" unless validator.valid?
          end

          def parse_expressions(expressions, validations)
            results = {
              account: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account)
            }

            expressions.each do |key, value|
              results[key.tr('-', '_').to_sym] = value
            end

            results[:branch] = Settings.github.default_branch if expressions[:branch].nil?

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
