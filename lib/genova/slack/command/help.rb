module Genova
  module Slack
    module Command
      class Help
        HELP = <<~DOC.freeze
          *Execute run task*
          ```
          # Statement mode.
          deploy:run-task reposisoty={repository} [branch={branch}] cluster={cluster} run-task={run task}

          # Statement mode with specify target.
          deploy:run-task repository={repository} [branch={branch}] target={target}
          ```

          *Service deploy*
          ```
          # Intractive mode.
          deploy[:service]

          # Statement mode.
          deploy[:service] repository={repository} [branch={branch}] cluster={cluster} service={service}

          # Statement mode with specify target.
          deploy[:service] repository={repository} [branch={branch}] target={target}
          ```

          *Scheduled task deploy*
          ```
          # Statement mode.
          deploy:scheduled-task repository={repository} [branch={branch}] cluster={cluster} scheduled-task-rule={scheduled task rule} scheduled-task-target={scheduled task target}

          # Statement mode with specify target.
          deploy:scheduled-task repository={repository} [branch={branch}] target={target}
          ```

          *Utility*
          ```
          # Get helpful message.
          help

          # Show deployment histories.
          history

          # Execute previous deployment again.
          redeploy

          # Show version.
          version
          ```
        DOC

        def self.call(_statements, _user, _parent_message_ts)
          client = Genova::Slack::Bot.new
          client.post_simple_message(text: HELP)
        end
      end
    end
  end
end
