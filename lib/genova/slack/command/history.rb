module Genova
  module Slack
    module Command
      class History
        def self.call(client, command, sub_commands, user, logger)
          # logger.info("Execute history command: (UNAME: #{client.owner}, user=#{data.user})")
          # logger.info("Input command: #{match['command']} #{match['expression']}")

          options = Genova::Slack::Util.history_options(user)

          if options.present?
            client.post_choose_history(options: options)
          else
            e = Exceptions::NotFoundError.new('History does not exist.')
            client.post_error(error: e, slack_user_id: data.user)
          end
        end
      end
    end
  end
end
