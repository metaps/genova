module Genova
  module Slack
    module Command
      class History
        def self.call(_statements, user, parent_message_ts)
          Genova::Slack::SessionStore.start!(parent_message_ts, user)

          client = Genova::Slack::Interactive::Bot.new(parent_message_ts:)
          client.ask_history(user:)
        end
      end
    end
  end
end
