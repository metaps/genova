module Genova
  module Slack
    module Command
      class Deploy
        def self.call(statements, user, parent_message_ts)
          client = Genova::Slack::Interactive::Bot.new(parent_message_ts: parent_message_ts)
          session_store = Genova::Slack::SessionStore.start!(parent_message_ts, user)

          type = case statements[:sub_command]
                 when 'run-task'
                   DeployJob.type.find_value(:run_task)
                 when 'scheduled-task'
                   DeployJob.type.find_value(:scheduled_task)
                 else
                   DeployJob.type.find_value(:service)
                 end

          if statements[:params].size.zero?
            client.ask_repository(user: user, user_name: user)
          else
            result = send("parse_#{type}", statements[:params])
            params = {
              type: type,
              repository: result[:repository],
              branch: result[:branch],
              cluster: result[:cluster],
              run_task: result[:run_task],
              service: result[:service],
              scheduled_task_rule: result[:scheduled_task_rule],
              scheduled_task_target: result[:scheduled_task_target]
            }

            session_store.save(params)

            params[:user] = user
            client.ask_confirm_deploy(params, mention: true)
          end
        end

        class << self
          private

          def parse_run_task(params)
            validations = {
              repository: String,
              branch: String,
              cluster: String,
              run_task: String
            }

            parse(params, validations)
          end

          def parse_service(params)
            validations = {
              repository: String,
              branch: String,
              cluster: String,
              service: String
            }

            parse(params, validations)
          end

          def parse_scheduled_task(params)
            validations = {
              repository: String,
              branch: String,
              cluster: String,
              scheduled_task_rule: String,
              scheduled_task_target: String
            }

            parse(params, validations)
          end

          def parse(params, validations)
            params[:branch] = Settings.github.default_branch if params[:branch].nil?

            if params.include?(:target)
              code_manager = Genova::CodeManager::Git.new(params[:repository], branch: params[:branch])
              target_config = code_manager.load_deploy_config.find_target(params[:target])
              target_config.delete(:name)

              params.merge!(target_config)
              params.delete(:target)
            end

            validator = HashValidator.validate(params, validations)
            raise Genova::Exceptions::InvalidArgumentError, "#{validator.errors.keys[0]}: #{validator.errors.params[0]}" unless validator.valid?

            params
          end
        end
      end
    end
  end
end
