module Genova
  module Slack
    module Command
      class History
        def self.call(_statements, user, parent_message_ts)
          session_store = Genova::Slack::SessionStore.new(parent_message_ts)
          session_store.start

          client = Genova::Slack::Bot.new(parent_message_ts: parent_message_ts)
          client.post_choose_history(user: user)
        end
      end
    end
  end
end
