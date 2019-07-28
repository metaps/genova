module Genova
  module Slack
    module Command
      class Help < SlackRubyBot::Commands::Base
        HELP = <<~DOC.freeze
          I am ECS deploy Bot.
          ```
          * deploy
            Run service deployment in interactive mode.
          * deploy <repository> <branch> service=<cluster>:<service>
            Run service deployment in command mode.
          * deploy <repository> <branch> scheduled-task=<cluster>:<scheduled task rule>:<scheduled task target>
            Run scheduled task deployment in command mode.
          * deploy <repository> <branch> target=<target name>
            Deploy by specifying target.
          * help
            Get this helpful message.
          * history
            Show execution history of deployment.
          * redeploy
            Run previous deployment again.
          ```
        DOC

        def self.call(client, data, match)
          logger.info("Execute help command: (UNAME: #{client.owner}, user=#{data.user})")
          logger.info("Input command: #{match['command']} #{match['expression']}")

          client.say(channel: data.channel, text: HELP)
        end
      end
    end
  end
end
