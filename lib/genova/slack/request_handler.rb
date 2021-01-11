module Genova
  module Slack
    class RequestHandler
      class << self
        WAIT_INTERVAL = 1
        NOTIFY_THRESHOLD = 4

        def handle_request(params)
          @params = params
          @bot = Genova::Slack::Bot.new
          @session_store = Genova::Slack::SessionStore.new(@params[:user][:id])

          action = @params.dig(:actions, 0)

          raise Genova::Exceptions::RoutingError, "`#{ation[:action_id]}` action does not exist." unless RequestHandler.respond_to?(action[:action_id], true)
          result = send(action[:action_id])

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
          @session_store.clear

          'Deployment has been canceled.'
        end

        def approve_repository
          value = @params.dig(:actions, 0, :selected_option, :value)
          params = {
            account: ENV.fetch('GITHUB_ACCOUNT'),
            base_path: nil,
            repository: nil
          }

          Settings.github.repositories.each.find {|k|
            if [k[:name], k[:alias]].include?(value)
              params[:base_path] = k[:base_path]
              params[:repository] = k[:name]

              break
            end
          }

          raise Genova::Exceptions::UnexpectedError, "#{value} repository does not exist." if params[:repository].nil?

          @session_store.add(params)

          jid = ::Github::RetrieveBranchWorker.perform_async(@params[:user][:id])
          ::Github::RetrieveBranchWatchWorker.perform_async(jid)

          "*Repository*\n#{params[:repository]}"
        end

        def approve_branch
          value = @params.dig(:actions, 0, :selected_option, :value)

          @session_store.add(branch: value)
          ::Slack::DeployClusterWorker.perform_async(@params[:user][:id])

          "*Branch*\n#{value}"
        end

        def approve_default_branch
          block_id = @params.dig(:actions, 0, :block_id)
          value = @params.dig(:state, :values, block_id.to_sym, :approve_branch, :selected_option, :value)

          @session_store.add(branch: value)
          ::Slack::DeployClusterWorker.perform_async(@params[:user][:id])

          "*Branch*\n#{value}"
        end

        def approve_cluster
          value = @params.dig(:actions, 0, :selected_option, :value)

          @session_store.add(cluster: value)
          ::Slack::DeployTargetWorker.perform_async(@params[:user][:id])

          "*Cluster*\n#{value}"
        end

        def approve_default_cluster
          block_id = @params.dig(:actions, 0, :block_id)
          value = @params.dig(:state, :values, block_id.to_sym, :approve_cluster, :selected_option, :value)

          @session_store.add(cluster: value)
          ::Slack::DeployTargetWorker.perform_async(@params[:user][:id])

          "*Cluster*\n#{value}"
        end

        def approve_target
          value = @params.dig(:actions, 0, :selected_option, :value)
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

          @session_store.add(params)
          ::Slack::DeployConfirmWorker.perform_async(@params[:user][:id])

          "*Target*\n#{value}"
        end

        def approve_deploy_from_history
          value = @params.dig(:actions, 0, :selected_option, :value)

          params = Genova::Slack::History.new(@params[:user][:id]).find(value)
          params[:confirm] = true

          @session_store.add(params)
          ::Slack::DeployHistoryWorker.perform_async(@params[:user][:id])

          'Checking history...'
        end

        def approve_deploy
          @bot.post_deploy_queue

          id = DeployJob.generate_id
          params = @session_store.params

          DeployJob.create(id: id,
                           type: params[:type],
                           status: DeployJob.status.find_value(:in_progress),
                           mode: DeployJob.mode.find_value(:slack),
                           slack_user_id: @params[:user][:id],
                           slack_user_name: @params[:user][:name],
                           account: params[:account],
                           repository: params[:repository],
                           branch: params[:branch],
                           cluster: params[:cluster],
                           base_path: params[:base_path],
                           run_task: params[:run_task],
                           service: params[:service],
                           scheduled_task_rule: params[:scheduled_task_rule],
                           scheduled_task_target: params[:scheduled_task_target])

          ::Slack::DeployWorker.perform_async(id)
          @session_store.clear

          'Start deployment'
        end
      end
    end
  end
end
