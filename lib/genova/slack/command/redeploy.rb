module Genova
  module Slack
    module Command
      class Redeploy
        def self.call(_statements, user, parent_message_ts)
          session_store = Genova::Slack::SessionStore.start!(parent_message_ts, user)

          client = Genova::Slack::Interactive::Bot.new(parent_message_ts: parent_message_ts)
          history = Genova::Slack::Interactive::History.new(user).last

          if history.present?
            session_store.save(history)
            params = {
              user: user,
              type: history[:type],
              account: history[:account],
              repository: history[:repository],
              branch: history[:branch],
              tag: history[:tag],
              cluster: history[:cluster],
              base_path: history[:base_path],
              run_task: history[:run_task],
              service: history[:service],
              scheduled_task_rule: history[:scheduled_task_rule],
              scheduled_task_target: history[:scheduled_task_target]
            }

            client.ask_confirm_deploy(params, true, true)
          else
            e = Exceptions::NotFoundError.new('History does not exist.')
            client.error(error: e, slack_user_id: user)
          end
        end
      end
    end
  end
end
