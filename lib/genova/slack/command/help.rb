module Genova
  module Slack
    module Command
      class Help < SlackRubyBot::Commands::Base
        HELP = <<~DOC.freeze
          ```
          I am ECS deploy Bot.

          General
          -------
          deploy          - Run deploy in interactive mode.
          deploy {repository} {branch} {cluster}:{service}
                          - Run deploy in command mode.
                            repository: Target repository (e.g. xxx-www).
                            branch: Target branch (e.g. feature/xxx).
                            cluster: ECS cluster name.
                            service: ECS service name.
          help            - Get this helpful message.
          history         - Show recently executed deploy command.
          redeploy        - Re-execute last deployment.
          ```
        DOC

        def self.call(client, data, _match)
          logger.info "Execute help command: (UNAME: #{client.owner}, user=#{data.user})"

          client.say(channel: data.channel, text: HELP)
        end
      end
    end
  end
end
