module Genova
  module Slack
    class RequestHandler
      class << self
        def handle_request(payload_body, logger = nil)
          return if payload_body.blank?

          @payload_body = payload_body
          @logger = logger || ::Logger.new(nil)
          @bot = Genova::Slack::Bot.new
          @callback = Genova::Slack::CallbackIdManager.find(@payload_body[:callback_id])

          raise Exceptions::RoutingError, "No route. [#{@callback[:action]}]" unless RequestHandler.respond_to?(@callback[:action], true)

          send(@callback[:action])
        end

        private

        def choose_deploy_branch
          selected_value = @payload_body.dig(:actions, 0, :selected_options, 0, :value)
          selected_base_path = nil
          selected_repository = nil

          Settings.github.repositories.each do |repository|
            if repository[:name] == selected_value || repository[:alias] == selected_value
              selected_base_path = repository[:base_path]
              selected_repository = repository[:name]

              break
            end
          end

          if selected_repository.present?
            result = {
              fields: [
                {
                  title: 'Repository',
                  value: selected_repository
                }
              ]
            }

            @logger.info('Invoke Github::RetrieveBranchWorker')

            params = {
              account: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account),
              repository: selected_repository,
              response_url: @payload_body[:response_url],
              base_path: selected_base_path
            }

            id = Genova::Sidekiq::Queue.add(params)

            jid = ::Github::RetrieveBranchWorker.perform_async(id)
            ::Github::RetrieveBranchWatchWorker.perform_async(jid)
          else
            result = cancel_message
          end

          result
        end

        def choose_deploy_cluster
          submit_value = @payload_body.dig(:actions, 0, :value)

          if submit_value == 'approve' || submit_value.nil?
            selected_branch = @payload_body.dig(:actions, 0, :selected_options, 0, :value) || Settings.github.default_branch
            result = {
              fields: [
                {
                  title: 'Branch',
                  value: selected_branch
                }
              ]
            }

            params = {
              account: @callback[:account],
              repository: @callback[:repository],
              branch: selected_branch,
              base_path: @callback[:base_path]
            }

            id = Genova::Sidekiq::Queue.add(params)
            ::Slack::DeployClusterWorker.perform_async(id)
          else
            result = cancel_message
          end

          result
        end

        def choose_deploy_target
          submit_value = @payload_body.dig(:actions, 0, :value)

          if submit_value == 'approve' || submit_value.nil?
            selected_cluster = @payload_body.dig(:actions, 0, :selected_options, 0, :value)

            selected_cluster = @payload_body.dig(:original_message, :attachments, 0, :actions, 0, :selected_options, 0, :value) if selected_cluster.nil?

            result = {
              fields: [
                {
                  title: 'Cluster',
                  value: selected_cluster
                }
              ]
            }

            params = {
              account: @callback[:account],
              repository: @callback[:repository],
              branch: @callback[:branch],
              cluster: selected_cluster,
              base_path: @callback[:base_path]
            }

            id = Genova::Sidekiq::Queue.add(params)
            ::Slack::DeployTargetWorker.perform_async(id)
          else
            result = cancel_message
          end

          result
        end

        def confirm_deploy
          submit_value = @payload_body.dig(:actions, 0, :value)

          if submit_value == 'approve' || submit_value.nil?
            selected_target = @payload_body.dig(:actions, 0, :selected_options, 0, :value)

            selected_target = @payload_body.dig(:original_message, :attachments, 0, :actions, 0, :selected_options, 0, :value) if selected_target.nil?

            result = {
              fields: [
                {
                  title: 'Target',
                  value: selected_target
                }
              ]
            }

            split = selected_target.split(':')
            type = split[0].to_sym

            params = {
              account: @callback[:account],
              repository: @callback[:repository],
              branch: @callback[:branch],
              cluster: @callback[:cluster],
              base_path: @callback[:base_path],
              type: DeployJob.type.find_value(type)
            }

            case type
            when :run_task
              params[:run_task] = split[1]
            when :service
              params[:service] = split[1]
            when :scheduled_task
              params[:scheduled_task_rule] = split[1]
              params[:scheduled_task_target] = split[2]
            end

            id = Genova::Sidekiq::Queue.add(params)
            ::Slack::DeployConfirmWorker.perform_async(id)
          else
            result = cancel_message
          end

          result
        end

        def confirm_deploy_from_history
          selected_history = @payload_body.dig(:actions, 0, :selected_options, 0, :value)
          slack_user_id = @payload_body[:user][:id]

          if selected_history.present?
            params = Genova::Slack::History.new(slack_user_id).find(selected_history)

            result = {
              fields: [
                {
                  title: 'Repository',
                  value: "#{params[:account]}/#{params[:repository]}"
                },
                {
                  title: 'Branch',
                  value: params[:branch]
                },
                {
                  title: 'Cluster',
                  value: params[:cluster]
                }
              ]
            }

            case params[:type]
            when DeployJob.type.find_value(:run_task)
              result[:fields] << {
                title: 'Run task',
                value: params[:run_task]
              }
            when DeployJob.type.find_value(:service)
              result[:fields] << {
                title: 'Service',
                value: params[:service]
              }
            when DeployJob.type.find_value(:scheduled_task)
              result[:fields] << {
                title: 'Scheduled task rule',
                value: params[:scheduled_task_rule]
              }
              result[:fields] << {
                title: 'Scheduled task target',
                value: params[:scheduled_task_target]
              }
            end

            id = Genova::Sidekiq::Queue.add(params)
            ::Slack::DeployHistoryWorker.perform_async(id)

          else
            result = cancel_message
          end

          result
        end

        def execute_deploy
          selected_button = @payload_body.dig(:actions, 0, :value)

          if selected_button == 'approve'
            result = {
              fields: [
                {
                  title: 'Confirm deployment',
                  value: selected_button
                }
              ]
            }

            @logger.info('Invoke Slack::DeployWorker')
            @bot.post_deploy_queue

            id = DeployJob.generate_id

            DeployJob.create(id: id,
                             type: @callback[:type],
                             status: DeployJob.status.find_value(:in_progress),
                             mode: DeployJob.mode.find_value(:slack),
                             slack_user_id: @payload_body[:user][:id],
                             slack_user_name: @payload_body[:user][:name],
                             account: @callback[:account],
                             repository: @callback[:repository],
                             branch: @callback[:branch],
                             cluster: @callback[:cluster],
                             base_path: @callback[:base_path],
                             run_task: @callback[:run_task],
                             service: @callback[:service],
                             scheduled_task_rule: @callback[:scheduled_task_rule],
                             scheduled_task_target: @callback[:scheduled_task_target])

            ::Slack::DeployWorker.perform_async(id)
          else
            result = cancel_message
          end

          result
        end

        def cancel_message
          {
            text: 'Deployment has been canceled.'
          }
        end
      end
    end
  end
end
