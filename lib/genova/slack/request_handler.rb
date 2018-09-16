module Genova
  module Slack
    class RequestHandler
      WAIT_INTERVAL = 3
      WAIT_LONG_TIME = 6

      class << self
        def handle_request(payload_body, logger)
          return if payload_body.blank?

          @payload_body = payload_body
          @logger = logger
          @bot = Genova::Slack::Bot.new

          @callback = Genova::Slack::CallbackIdManager.find(@payload_body[:callback_id])

          case @callback[:action]
          when 'post_history' then
            result = confirm_deploy_from_history
          when 'post_repository' then
            result = choose_deploy_branch
          when 'post_branch' then
            result = choose_deploy_cluster
          when 'post_cluster' then
            result = choose_deploy_target
          when 'post_target' then
             result = confirm_deploy
          when 'post_deploy' then
            result = execute_deploy
          else
            raise RoutingError, 'No route.'
          end

          result
        end

        private

        def choose_deploy_branch
          selected_repository = @payload_body.dig(:actions, 0, :selected_options, 0, :value)

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

            id = Genova::Sidekiq::Queue.add(
              account: Settings.github.account,
              repository: selected_repository,
              response_url: @payload_body[:response_url]
            )
            ::Github::RetrieveBranchWorker.perform_async(id)

            Thread.new do
              watch_change_status(id)
            end
          else
            result = cancel_message
          end

          result
        end

        def watch_change_status(id)
          start_time = Time.new.utc.to_i

          loop do
            sleep(WAIT_INTERVAL)

            next if Time.new.utc.to_i - start_time < WAIT_LONG_TIME
            job = Genova::Sidekiq::Queue.find(id)

            if job.status == Genova::Sidekiq::Queue.status.find_value(:in_progress)
              Genova::Slack::Bot.new.post_simple_message(text: 'Retrieving repository. It takes time because the repository is large. Please wait for a while...')
            end

            break
          end
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

            @bot.post_choose_cluster(
              account: @callback[:account],
              repository: @callback[:repository],
              branch: selected_branch
            )
          else
            result = cancel_message
          end

          result
        end

        def choose_deploy_target
          submit_value = @payload_body.dig(:actions, 0, :value)

          if submit_value == 'approve' || submit_value.nil?
            selected_cluster = @payload_body.dig(:actions, 0, :selected_options, 0, :value)

            if selected_cluster.nil?
              selected_cluster = @payload_body.dig(:original_message, :attachments, 0, :actions, 0, :selected_options, 0, :value)
            end

            result = {
              fields: [
                {
                  title: 'Cluster',
                  value: selected_cluster
                }
              ]
            }

            @bot.post_choose_target(
              account: @callback[:account],
              repository: @callback[:repository],
              branch: @callback[:branch],
              cluster: selected_cluster
            )
          else
            result = cancel_message
          end

          result
        end

        def confirm_deploy
          submit_value = @payload_body.dig(:actions, 0, :value)

          if submit_value == 'approve' || submit_value.nil?
            selected_target = @payload_body.dig(:actions, 0, :selected_options, 0, :value)

            if selected_target.nil?
              selected_target = @payload_body.dig(:original_message, :attachments, 0, :actions, 0, :selected_options, 0, :value)
            end

            result = {
              fields: [
                {
                  title: 'Target',
                  value: selected_target
                }
              ]
            }

            params = {
              account: @callback[:account],
              repository: @callback[:repository],
              branch: @callback[:branch],
              cluster: @callback[:cluster]
            }

            split = selected_target.split(':')

            if split[0] == 'service'
              params[:service] = split[1]
            elsif split[0] == 'scheduled_task'
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

            if params[:service].present?
              result[:fields] << {
                title: 'Service',
                value: params[:service]
              }
            else
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
                             status: DeployJob.status.find_value(:in_progress).to_s,
                             mode: DeployJob.mode.find_value(:slack).to_s,
                             slack_user_id: @payload_body[:user][:id],
                             slack_user_name: @payload_body[:user][:name],
                             account: @callback[:account],
                             repository: @callback[:repository],
                             branch: @callback[:branch],
                             cluster: @callback[:cluster],
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

      class RoutingError < Error; end
    end
  end
end
