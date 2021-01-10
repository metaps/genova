module Genova
  module Slack
    class RequestHandler
      class << self
        def handle_request(params)
          @params = params
          @logger = ::Logger.new(STDOUT)
          @bot = Genova::Slack::Bot.new

          raise Genova::Exceptions::RoutingError, "`#{params[:action]}` action does not exist." unless RequestHandler.respond_to?(params[:action], true)

          result = send(params[:action])

          result = {
            update_original: true,
            blocks: [{
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: result
              }
            }]
          }

          RestClient.post(@params[:response_url], result.to_json, content_type: :json)
        end

        private

        def cancel
          'Deployment has been canceled.'
        end

        def choose_deploy_branch
          params = {
            account: ENV.fetch('GITHUB_ACCOUNT'),
            base_path: nil,
            repository: nil
          }

          Settings.github.repositories.each.find {|k|
            if [k[:name], k[:alias]].include?(@params[:value])
              params[:base_path] = k[:base_path]
              params[:repository] = k[:name]

              break
            end
          }

          raise Genova::Exceptions::UnexpectedError, "#{@params[:value]} repository does not exist." if params[:repository].nil?
          result = "*Repository*\n#{params[:repository]}"

          @bot.post_choose_branch(params)

            #::Github::RetrieveBranchWatchWorker.perform_async(jid)

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
              account: @request[:account],
              repository: @request[:repository],
              branch: selected_branch,
              base_path: @request[:base_path]
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
              account: @request[:account],
              repository: @request[:repository],
              branch: @request[:branch],
              cluster: selected_cluster,
              base_path: @request[:base_path]
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
              account: @request[:account],
              repository: @request[:repository],
              branch: @request[:branch],
              cluster: @request[:cluster],
              base_path: @request[:base_path],
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
          selected_history = @payload_body.dig(:actions, 0, :selected_option, :value)
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
                             type: @request[:type],
                             status: DeployJob.status.find_value(:in_progress),
                             mode: DeployJob.mode.find_value(:slack),
                             slack_user_id: @payload_body[:user][:id],
                             slack_user_name: @payload_body[:user][:name],
                             account: @request[:account],
                             repository: @request[:repository],
                             branch: @request[:branch],
                             cluster: @request[:cluster],
                             base_path: @request[:base_path],
                             run_task: @request[:run_task],
                             service: @request[:service],
                             scheduled_task_rule: @request[:scheduled_task_rule],
                             scheduled_task_target: @request[:scheduled_task_target])

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
