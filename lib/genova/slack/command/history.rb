module Genova
  module Slack
    module Command
      class History
        def self.call(client, statements, user)
          options = Genova::Slack::Util.history_options(user)

          if options.present?
            client.post_choose_history(options: options)
          else
            e = Exceptions::NotFoundError.new('History does not exist.')
            client.post_error(error: e, slack_user_id: user)
          end
        end
      end
    end
  end
end
