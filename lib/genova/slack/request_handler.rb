module Genova
  module Slack
    class RequestHandler
      class << self
        def call(payload)
          @payload = payload
          @thread_ts = @payload[:container][:thread_ts]
          @session_store = Genova::Slack::SessionStore.load(@thread_ts)
          @logger = ::Logger.new($stdout, level: Settings.logger.level)

          action = @payload.dig(:actions, 0)

          raise Genova::Exceptions::RoutingError, "`#{ation[:action_id]}` action does not exist." unless RequestHandler.respond_to?(action[:action_id], true)

          result = {
            update_original: true,
            blocks: [BlockKit::Helper.section(send(action[:action_id]))],
            thread_ts: @thread_ts
          }

          RestClient.post(@payload[:response_url], result.to_json, content_type: :json)
        end

        private

        def cancel
          params = @session_store.params
          Genova::Utils::DeployTransaction.new(params[:repository], @logger).cancel if params[:repository].present?

          'Deployment was canceled.'
        end

        def approve_repository
          value = @payload.dig(:actions, 0, :selected_option, :value)
          params = {
            account: ENV.fetch('GITHUB_ACCOUNT')
          }

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

        def approve_target
          value = @payload.dig(:actions, 0, :selected_option, :value)
          targets = value.split(':')
          type = targets[0].to_sym

          params = {
            type: type
          }

          case type
          when :run_task
            params[:run_task] = targets[1]
          when :service
            params[:service] = targets[1]
          when :scheduled_task
            params[:scheduled_task_rule] = targets[1]
            params[:scheduled_task_target] = targets[2]
          end

          @session_store.save(params)
          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Target', value)
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
      end
    end
  end
end
