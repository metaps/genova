module Genova
  module Slack
    class RequestHandler
      class << self
        def handle_request(params)
          @params = params
          @thread_ts = @params[:container][:thread_ts]
          @session_store = Genova::Slack::SessionStore.load(@thread_ts)

          action = @params.dig(:actions, 0)

          raise Genova::Exceptions::RoutingError, "`#{ation[:action_id]}` action does not exist." unless RequestHandler.respond_to?(action[:action_id], true)

          result = {
            update_original: true,
            blocks: [BlockKit::Helper.section(send(action[:action_id]))],
            thread_ts: @thread_ts
          }

          RestClient.post(@params[:response_url], result.to_json, content_type: :json)
        end

        private

        def cancel
          'Deployment was canceled.'
        end

        def approve_repository
          value = @params.dig(:actions, 0, :selected_option, :value)
          params = {
            account: ENV.fetch('GITHUB_ACCOUNT')
          }

          Settings.github.repositories.each.find do |k|
            next unless k[:name] == value || k[:alias].present? && k[:alias] == value

            params[:repository] = k[:name]
            params[:alias] = k[:alias]
            break
          end

          raise Genova::Exceptions::UnexpectedError, "#{value} repository does not exist." if params[:repository].nil?

          @session_store.save(params)
          jid = ::Github::RetrieveBranchWorker.perform_async(@thread_ts)

          @session_store.save(retrieve_branch_jid: jid)
          ::Github::RetrieveBranchWatchWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Repository', params[:repository])
        end

        def approve_branch
          value = @params.dig(:actions, 0, :selected_option, :value)

          @session_store.save(branch: value)
          ::Slack::DeployClusterWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Branch', value)
        end

        def approve_tag
          value = @params.dig(:actions, 0, :selected_option, :value)

          @session_store.save(tag: value)
          ::Slack::DeployClusterWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Tag', value)
        end

        def approve_cluster
          value = @params.dig(:actions, 0, :selected_option, :value)

          @session_store.save(cluster: value)
          ::Slack::DeployTargetWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Cluster', value)
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

          @session_store.save(params)
          ::Slack::DeployConfirmWorker.perform_async(@thread_ts)

          BlockKit::Helper.section_field('Target', value)
        end

        def approve_deploy_from_history
          value = @params.dig(:actions, 0, :selected_option, :value)

          params = Genova::Slack::Interactive::History.new(@params[:user][:id]).find!(value)

          @session_store.save(params)
          ::Slack::DeployHistoryWorker.perform_async(@thread_ts)

          'Checking history...'
        end

        def approve_deploy
          params = @session_store.params
          params[:deploy_job_id] = DeployJob.generate_id

          @session_store.save(params)

          DeployJob.create(id: params[:deploy_job_id],
                           type: params[:type],
                           alias: params[:alias],
                           status: DeployJob.status.find_value(:in_progress),
                           mode: DeployJob.mode.find_value(:slack),
                           slack_user_id: @params[:user][:id],
                           slack_user_name: @params[:user][:name],
                           account: params[:account],
                           repository: params[:repository],
                           branch: params[:branch],
                           tag: params[:tag],
                           cluster: params[:cluster],
                           run_task: params[:run_task],
                           service: params[:service],
                           scheduled_task_rule: params[:scheduled_task_rule],
                           scheduled_task_target: params[:scheduled_task_target])

          ::Slack::DeployWorker.perform_async(@thread_ts)

          'Deployment started.'
        end
      end
    end
  end
end
