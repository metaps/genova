module CI
  module Slack
    module Command
      class Help < SlackRubyBot::Commands::Base
        HELP = <<~DOC.freeze
          ```
          I am ECS deploy Bot.

          General
          -------
          deploy          - Run deploy in interactive mode.
          deploy {repository} {branch} {environment}
                          - Run deployment in command base.
                            repository: Repository name of GitHub (e.g. xxx-www).
                            branch: Branch naem of Repository (e.g. feature/xxx).

                            environment: development or staging or production.
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
