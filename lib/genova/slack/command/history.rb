module Genova
  module Slack
    module Command
      class History
        def self.call(client, _statements, user)
          client.post_choose_history(user: user)
        end
      end
    end
  end
end
