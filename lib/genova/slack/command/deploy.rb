module Genova
  module Slack
    module Command
      class Deploy
        def self.call(client, statements, user)
          session_store = Genova::Slack::SessionStore.new(user)
          session_store.start

          begin
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
                scheduled_task_target: results[:scheduled_task_target]
              }

              params[:base_path] = Genova::Config::SettingsHelper.find_repository!(results[:repository])
              client.post_confirm_deploy(params)
            end
          rescue => e
            session_store.clear
            raise e
          end
        end

        class << self
          private

          def parse_run_task(params)
            validations = {
              account: String,
              repository: String,
              branch: String,
              cluster: String,
              run_task: String
            }

            parse(params, validations)
          end

          def parse_service(params)
            validations = {
              account: String,
              repository: String,
              branch: String,
              cluster: String,
              service: String
            }

            parse(params, validations)
          end

          def parse_scheduled_task(params)
            validations = {
              account: String,
              repository: String,
              branch: String,
              cluster: String,
              scheduled_task_rule: String,
              scheduled_task_target: String
            }

            parse(params, validations)
          end

          def validate!(values, validations)
            validator = HashValidator.validate(values, validations)
            raise Genova::Exceptions::InvalidArgumentError, "#{validator.errors.keys[0]}: #{validator.errors.values[0]}" unless validator.valid?
          end

          def parse(params, validations)
            params[:account] = ENV.fetch('GITHUB_ACCOUNT')
            params[:branch] = Settings.github.default_branch if params[:branch].nil?

            if params.include?(:target)
              code_manager = Genova::CodeManager::Git.new(params[:account], params[:repository], branch: params[:branch])
              target = code_manager.load_deploy_config.target(params[:target])

              params.merge!(target)
              params.delete(params[:target])
            end

            validate!(params, validations)

            params
          end
        end
      end
    end
  end
end
