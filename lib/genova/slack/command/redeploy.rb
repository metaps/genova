module Genova
  module Slack
    module Command
      class Redeploy
        def self.call(_statements, user, parent_message_ts)
          session_store = Genova::Slack::SessionStore.start!(parent_message_ts, user)

          client = Genova::Slack::Interactive::Bot.new(parent_message_ts: parent_message_ts)
          history = Genova::Slack::Interactive::History.new(user).last

          if history.present?
            params = history.clone
            params[:user] = user

            session_store.save(history)
            client.ask_confirm_deploy(params, mention: true)
          else
            e = Exceptions::NotFoundError.new('History does not exist.')
            client.error(error: e, slack_user_id: user)
          end
        end
      end
    end
  end
end
