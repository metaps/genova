module Genova
  module Slack
    module Command
      class Help < SlackRubyBot::Commands::Base
        HELP = <<~DOC.freeze
          Hello, I'm ECS deploy Bot.

          *Service deploy*
          - `deploy[:service]` Run intractive mode.
          - `deploy[:service] <repository>[:<branch>] cluster=<cluster> service=<service>` Run statement mode.
          - `deploy[:service] <repository>[:<branch>] target=<target>` Specify target and run statement mode.

          *Execute run task*
          - `deploy:run-task <repository>[:<branch>] cluster=<cluster> run-task=<run task>` Run statement mode.
          - `deploy:run-task <repository>[:<branch>] target=<target>` Specify target and run task.

          *Scheduled task deploy*
          - `deploy:scheduled-task <repository>[:<branch>] cluster=<cluster> scheduled-task-rule=<scheduled task rule> scheduled-task-target=<scheduled task target>` Run statement mode.
          - `deploy:scheduled-task <repository>[:<branch>] target=<target>` Specify target and run scheduled task.

          *Util*
          - `help` Get helpful message.
          - `history` Show deployment histories.
          - `redeploy` Run previous deployment again.
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
