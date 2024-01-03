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

          send(action[:action_id])
        end

        private

        def show_message(message)
          params = {
            update_original: true,
            blocks: [BlockKit::Helper.section(message)],
            thread_ts: @thread_ts
          }

          RestClient.post(@payload[:response_url], params.to_json, content_type: :json)
        end

        def submit_cancel
          params = @session_store.params
          Genova::Deploy::Transaction.new(params[:repository]).cancel if params[:repository].present?

          show_message('Deployment was canceled.')
        end

        def selected_repository
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

          @session_store.merge(params)
          ::Github::RetrieveBranchWorker.perform_async(@thread_ts)

          show_message(BlockKit::Helper.section_field('Repository', params[:repository]))
        end

        def selected_workflow
          value = @payload.dig(:actions, 0, :selected_option, :value)
          @session_store.merge({ name: value })

          bot = Interactive::Bot.new(parent_message_ts: @thread_ts)
          bot.ask_confirm_workflow_deploy(name: value)

          show_message(BlockKit::Helper.section_field('Workflow', value))
        end

        def selected_branch
          value = @payload.dig(:actions, 0, :selected_option, :value)

          @session_store.merge({ branch: value })
          ::Slack::DeployClusterWorker.perform_async(@thread_ts)

          show_message(BlockKit::Helper.section_field('Branch', value))
        end

        def selected_tag
          value = @payload.dig(:actions, 0, :selected_option, :value)

          @session_store.merge({ tag: value })
          ::Slack::DeployClusterWorker.perform_async(@thread_ts)

          show_message(BlockKit::Helper.section_field('Tag', value))
        end

        def selected_cluster
          value = @payload.dig(:actions, 0, :selected_option, :value)

          @session_store.merge({ cluster: value })
          ::Slack::DeployTargetWorker.perform_async(@thread_ts)

          show_message(BlockKit::Helper.section_field('Cluster', value))
        end

        def selected_run_task
          params = {
            type: DeployJob.type.find_value(:run_task),
            run_task: @payload.dig(:actions, 0, :selected_option, :value)
          }
          @session_store.merge(params)
        end

        def submit_run_task
          params = {
            override_container: @payload[:state][:values][:run_task_override_container][:submit_run_task_override_container][:value],
            override_command: @payload[:state][:values][:run_task_override_command][:submit_run_task_override_command][:value]
          }
          @session_store.merge(params)

          return if @session_store.params[:run_task].nil?

          value = @session_store.params[:run_task]
          value += "Override\n`#{params[:override_container]} / #{params[:override_command]}`" if params[:override_container].present? && params[:override_command].present?

          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)
          show_message(BlockKit::Helper.section_field('Run task', value))
        end

        def selected_service
          params = {
            type: DeployJob.type.find_value(:service),
            service: @payload.dig(:actions, 0, :selected_option, :value)
          }

          @session_store.merge(params)
          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)

          show_message(BlockKit::Helper.section_field('Service', params[:service]))
        end

        def selected_scheduled_task
          value = @payload.dig(:actions, 0, :selected_option, :value)
          targets = value.split(':')

          params = {
            type: DeployJob.type.find_value(:scheduled_task),
            scheduled_task_rule: targets[0],
            scheduled_task_target: targets[1]
          }

          @session_store.merge(params)
          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)

          show_message(BlockKit::Helper.section_field('Scheduled task', "#{params[:scheduled_task_rule]} / #{params[:scheduled_task_target]}"))
        end

        def submit_history
          value = @payload.dig(:actions, 0, :selected_option, :value)

          params = Genova::Slack::Interactive::History.new(@payload[:user][:id]).find!(value)

          @session_store.merge(params)
          ::Slack::DeployHistoryWorker.perform_async(@thread_ts)

          show_message('Checking history...')
        end

        def submit_deploy
          permission = Interactive::Permission.new(@payload[:user][:id])
          raise Genova::Exceptions::SlackPermissionDeniedError, "User #{@payload[:user][:id]} does not have execute permission." unless permission.allow_cluster?(@session_store.params[:cluster]) || permission.allow_repository?(@session_store.params[:repository])

          ::Slack::DeployWorker.perform_async(@thread_ts)

          show_message('Deployment started.')
        end

        def submit_stop
          deploy_job = DeployJob.find(@payload.dig(:actions, 0, :value))

          if deploy_job.status == DeployJob.status.find_value(:initial) || deploy_job.status == DeployJob.status.find_value(:provisioning)
            deploy_job.update_status_reserved_cancel
            show_message('Cancellation request succeeded.')
          else
            bot = Interactive::Bot.new(parent_message_ts: @thread_ts)
            bot.send_message('Oops! Cancellation failed. Deployment is already in progress.')
          end
        end

        def selected_workflow_deploy
          permission = Interactive::Permission.new(@payload[:user][:id])
          raise Genova::Exceptions::SlackPermissionDeniedError, "User #{@payload[:user][:id]} does not have execute permission." unless permission.allow_workflow?(@session_store.params[:workflow])

          ::Slack::WorkflowDeployWorker.perform_async(@thread_ts)

          show_message('Workflow deployment started.')
        end
      end
    end
  end
end
