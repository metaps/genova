module Genova
  module Slack
    module Command
      class Help
        HELP = <<~DOC.freeze
          *Service deploy*
          ```
          # Run intractive mode.
          deploy[:service]

          # Run statement mode.
          deploy[:service] repository={repository} [branch={branch}] cluster={cluster} service={service}

          # Specify target and run statement mode.
          deploy[:service] repository={repository} [branch={branch}] target={target}
          ```

          *Execute run task*
          ```
          # Run statement mode.
          deploy:run-task reposisoty={repository} [branch={branch}] cluster={cluster} run-task=<run task>

          # Specify target and run statement mode.
          deploy:run-task repository={repository} [branch={branch}] target={target}
          ```

          *Scheduled task deploy*
          ```
          # Run statement mode.
          deploy:scheduled-task repository={repository} [branch={branch}] cluster={cluster} scheduled-task-rule={scheduled task rule} scheduled-task-target={scheduled task target}

          # Specify target and run statement mode.
          deploy:scheduled-task repository={repository} [branch={branch}] target={target}
          ```

          *Utility*
          ```
          # Get helpful message.
          help

          # Show deployment histories.
          history

          # Run previous deployment again.
          redeploy

          # Show version.
          version
          ```
        DOC

        def self.call(client, _statements, _user)
          client.post_simple_message(text: HELP)
        end
      end
    end
  end
end
