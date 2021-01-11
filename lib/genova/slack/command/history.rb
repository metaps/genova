module Genova
  module Slack
    module Command
      class History
        def self.call(client, _statements, user)
          session_store = Genova::Slack::SessionStore.new(user)
          session_store.start

          client.post_choose_history(user: user)
        rescue => e
          puts e.class
          session_store.clear
        end
      end
    end
  end
end
