module Genova
  module Slack
    class RequestHandler
      class << self
        def call(payload)
          @payload = payload
          @thread_ts = @payload[:container][:thread_ts]
          @session_store = Genova::Slack::SessionStore.load(@thread_ts)

          action = @payload.dig(:actions, 0)

          raise Genova::Exceptions::RoutingError, "`#{action[:action_id]}` action does not exist." unless RequestHandler.respond_to?(action[:action_id], true)

          content = send(action[:action_id])
          return if content.nil?

          result = {
            update_original: true,
            blocks: [BlockKit::Helper.section(content)],
            thread_ts: @thread_ts
          }

          RestClient.post(@payload[:response_url], result.to_json, content_type: :json)
        end

        private

        def cancel
          params = @session_store.params
          Genova::Deploy::Transaction.new(params[:repository]).cancel if params[:repository].present?

          'Deployment was canceled.'
        end

        def approve_repository
          value = @payload.dig(:actions, 0, :selected_option, :value)
          params = {}

          repositories = Settings.github.repositories || []
          repositories.each.find do |k|
            next unless k[:name] == value || k[:alias].present? && k[:alias] == value

            params[:repository] = k[:name]
            params[:alias] = k[:alias]
            break
          end

          raise Genova::Exceptions::UnexpectedError, "#{value} repository does not exist." if params[:repository].nil?

          @session_store.save(params)
          ::Github::RetrieveBranchWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Repository', params[:repository])
        end

        def approve_workflow
          value = @payload.dig(:actions, 0, :selected_option, :value)
          @session_store.save(name: value)

          bot = Interactive::Bot.new(parent_message_ts: @thread_ts)
          bot.ask_confirm_workflow_deploy(name: value)

          BlockKit::Helper.section_field('Workflow', value)
        end

        def approve_branch
          value = @payload.dig(:actions, 0, :selected_option, :value)

          @session_store.save(branch: value)
          ::Slack::DeployClusterWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Branch', value)
        end

        def approve_tag
          value = @payload.dig(:actions, 0, :selected_option, :value)

          @session_store.save(tag: value)
          ::Slack::DeployClusterWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Tag', value)
        end

        def approve_cluster
          value = @payload.dig(:actions, 0, :selected_option, :value)

          @session_store.save(cluster: value)
          ::Slack::DeployTargetWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Cluster', value)
        end

        def approve_run_task
          value = @payload.dig(:actions, 0, :selected_option, :value)
          targets = value.split(':')
          params = {
            type: DeployJob.type.find_value(:run_task),
            run_task: targets[1]
          }
          @session_store.save(params)

          nil
        end

        def submit_run_task
          params = {
            override_container: @payload[:state][:values][:run_task_override_container][:submit_run_task_override_container][:value],
            override_command: @payload[:state][:values][:run_task_override_command][:submit_run_task_override_command][:value]
          }
          @session_store.save(params)

          value = @session_store.params[:run_task]

          value += " (#{params[:override_container]}:#{params[:override_command]})" if params[:override_container].present? && params[:override_command].present?

          return if @session_store.params[:run_task].nil?

          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)
          BlockKit::Helper.section_field('Run task', value)
        end

        def approve_service
          value = @payload.dig(:actions, 0, :selected_option, :value)
          targets = value.split(':')

          params = {
            type: DeployJob.type.find_value(:service),
            service: targets[1]
          }

          @session_store.save(params)
          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Service', params[:service])
        end

        def approve_scheduled_task
          value = @payload.dig(:actions, 0, :selected_option, :value)
          targets = value.split(':')

          params = {
            type: DeployJob.type.find_value(:scheduled_task),
            scheduled_task_rule: targets[1],
            scheduled_task_target: targets[2]
          }

          @session_store.save(params)
          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Scheduled task', "#{targets[1]} / #{targets[2]}")
        end

        def approve_deploy_from_history
          value = @payload.dig(:actions, 0, :selected_option, :value)

          params = Genova::Slack::Interactive::History.new(@payload[:user][:id]).find!(value)

          @session_store.save(params)
          ::Slack::DeployHistoryWorker.perform_async(@thread_ts)

          'Checking history...'
        end

        def approve_deploy
          permission = Interactive::Permission.new(@payload[:user][:id])
          raise Genova::Exceptions::SlackPermissionDeniedError, "User #{@payload[:user][:id]} does not have execute permission." unless permission.allow_cluster?(@session_store.params[:cluster]) || permission.allow_repository?(@session_store.params[:repository])

          ::Slack::DeployWorker.perform_async(@thread_ts)

          'Deployment started.'
        end

        def approve_workflow_deploy
          permission = Interactive::Permission.new(@payload[:user][:id])
          raise Genova::Exceptions::SlackPermissionDeniedError, "User #{@payload[:user][:id]} does not have execute permission." unless permission.allow_workflow?(@session_store.params[:workflow])

          ::Slack::WorkflowDeployWorker.perform_async(@thread_ts)

          'Workflow deployment started.'
        end
      end
    end
  end
end
