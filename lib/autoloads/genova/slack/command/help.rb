module Genova
  module Slack
    module Command
      class Help
        def self.usage(user_id)
          client = ::Slack::Web::Client.new(token: Settings.slack.api_token)

          user_info = client.users_info(user: user_id)
          user_name = user_info.user.real_name

          <<~DOC.freeze
            Sending commands in the `@#{user_name} [COMMAND]` format to the bot provides various features to support Amazon ECS deployments.

            *Execute run task*
            ```
            # Statement mode.
            @#{user_name} deploy:run-task reposisoty={repository} [branch={branch}] cluster={cluster} run-task={run task}

            # Statement mode with specify target.
            @#{user_name} deploy:run-task repository={repository} [branch={branch}] target={target}
            ```

            *Service deploy*
            ```
            # Intractive mode.
            @#{user_name} deploy[:service]

            # Statement mode.
            @#{user_name} deploy[:service] repository={repository} [branch={branch}] cluster={cluster} service={service}

            # Statement mode with specify target.
            @#{user_name} deploy[:service] repository={repository} [branch={branch}] target={target}
            ```

            *Scheduled task deploy*
            ```
            # Statement mode.
            @#{user_name} deploy:scheduled-task repository={repository} [branch={branch}] cluster={cluster} scheduled-task-rule={scheduled task rule} scheduled-task-target={scheduled task target}

            # Statement mode with specify target.
            @#{user_name} deploy:scheduled-task repository={repository} [branch={branch}] target={target}
            ```

            *Support utilities*
            ```
            # Get helpful message.
            @#{user_name} help

            # Show deployment histories.
            @#{user_name} history

            # Execute previous deployment again.
            @#{user_name} redeploy

            # Show version.
            @#{user_name} version
            ```
          DOC
        end

        def self.call(statements, _user, _parent_message_ts)
          client = Genova::Slack::Interactive::Bot.new
          client.send_message(usage(statements[:mention_user_id]))
        end
      end
    end
  end
end
