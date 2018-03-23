module Genova
  module Slack
    module Command
      class Help < SlackRubyBot::Commands::Base
        HELP = <<~DOC.freeze
          ```
          I am ECS deploy Bot.

          Usage
          -----
          deploy
            Run service & scheduled task deployment in interactive mode.
          deploy {repository} {branch} {cluster}:{service}
            Run service & scheduled task deployment in command mode.
              repository: Source repository.
              branch: Source branch.
              cluster: Cluster name of deployment destination.
              service: Service name of deployment destination.
          deploy-scheduled-task
            Run scheduled task deployment in command mode. (Not implemented yet!)
          help
            Get this helpful message.
          history
            Show execution history of deployment.
          redeploy
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
