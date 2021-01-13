module Genova
  module Slack
    module Command
      class Redeploy
        def self.call(client, _statements, user)
          session_store = Genova::Slack::SessionStore.new(user)
          session_store.start

          begin
            history = Genova::Slack::History.new(user).last

            if history.present?
              session_store.add(history)
              params = {
                type: history[:type],
                account: history[:account],
                repository: history[:repository],
                branch: history[:branch],
                cluster: history[:cluster],
                base_path: history[:base_path],
                run_task: history[:run_task],
                service: history[:service],
                scheduled_task_rule: history[:scheduled_task_rule],
                scheduled_task_target: history[:scheduled_task_target]
              }
              client.post_confirm_deploy(params)
            else
              e = Exceptions::NotFoundError.new('History does not exist.')
              client.post_error(error: e, slack_user_id: user)
            end
          rescue
            session_store.clear
          end
        end
      end
    end
  end
end
