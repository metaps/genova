module Genova
  module Slack
    class Bot
      SUBMIT_APPROVE = {
        name: 'submit',
        text: 'Approve',
        type: 'button',
        style: 'primary',
        value: 'approve'
      }.freeze
      SUBMIT_CANCEL = {
        name: 'submit',
        text: 'Cancel',
        type: 'button',
        style: 'default',
        value: 'cancel'
      }.freeze

      def initialize(client = nil)
        @client = client || ::Slack::Web::Client.new(token: ENV.fetch('SLACK_API_TOKEN'))
        @channel = ENV.fetch('SLACK_CHANNEL')
        @ecs = Aws::ECS::Client.new
      end

      def post_simple_message(params)
        text = params[:text] || ''

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: escape_emoji(text),
          attachments: [
            color: Settings.slack.message.color.confirm,
            fields: params[:fields]
          ]
        )
      end

      def post_choose_history(params)
        callback_id = Genova::Slack::CallbackIdManager.create('confirm_deploy_from_history')

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          text: 'Please specify job to be redeployed.',
          attachments: [
            title: 'History',
            text: "#{ENV.fetch('GENOVA_URL')}/",
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            actions: [
              {
                name: 'history',
                text: 'Pick command...',
                type: 'select',
                options: params[:options]
              },
              SUBMIT_CANCEL
            ]
          ]
        )
      end

      def post_choose_repository
        callback_id = Genova::Slack::CallbackIdManager.create('choose_deploy_branch')

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            title: 'Target repository.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            actions: [
              {
                name: 'repository',
                text: 'Pick repository...',
                type: 'select',
                options: Genova::Slack::Util.repository_options
              },
              SUBMIT_CANCEL
            ]
          ]
        )
      end

      def post_choose_cluster(params)
        callback_id = Genova::Slack::CallbackIdManager.create('choose_deploy_target', params)
        options = Genova::Slack::Util.cluster_options(params[:account], params[:repository], params[:branch])
        selected_options = []

        if options.size.positive?
          first_option = options[0]
          selected_options = [
            {
              text: first_option[:text],
              value: first_option[:value]
            }
          ]
        end

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            title: 'Target cluster.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            actions: [
              {
                name: 'cluster',
                type: 'select',
                options: options,
                selected_options: selected_options
              },
              SUBMIT_APPROVE,
              SUBMIT_CANCEL
            ]
          ]
        )
      end

      def post_choose_target(params)
        callback_id = Genova::Slack::CallbackIdManager.create('confirm_deploy', params)
        option_groups = Genova::Slack::Util.target_options(
          params[:account],
          params[:repository],
          params[:branch],
          params[:cluster]
        )
        selected_options = []

        if option_groups.size.positive?
          first_option = nil

          option_groups.each do |option_group|
            first_option = option_group[:options][0] if option_group[:options].size.positive?
          end

          selected_options = [
            {
              text: first_option[:text],
              value: first_option[:value]
            }
          ]
        end

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            title: 'Deploy target.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            actions: [
              {
                name: 'cluster',
                type: 'select',
                option_groups: option_groups,
                selected_options: selected_options
              },
              SUBMIT_APPROVE,
              SUBMIT_CANCEL
            ]
          ]
        )
      end

      def post_confirm_deploy(params)
        if params[:confirm]
          fields = [
            {
              title: 'Repository',
              value: params[:repository]
            },
            {
              title: 'Branch',
              value: params[:branch]
            },
            {
              title: 'Cluster',
              value: params[:cluster]
            }
          ]

          if params[:service].present?
            fields << {
              title: 'Service',
              value: params[:service]
            }
          else
            fields << {
              title: 'Scheduled task rule',
              value: params[:scheduled_task_rule]
            }
            fields << {
              title: 'Scheduled task target',
              value: params[:scheduled_task_target]
            }
          end

          post_simple_message(fields: fields)
        end

        callback_id = Genova::Slack::CallbackIdManager.create('execute_deploy', params)
        fields = []

        latest_commit_id = git_latest_commit_id(params)
        deployed_commit_id = git_deployed_commit_id(params)

        value = if latest_commit_id == deployed_commit_id
                  'Commit ID is unchanged.'
                elsif deployed_commit_id.present?
                  github_client = Genova::Github::Client.new(params[:account], params[:repository])
                  "<#{github_client.build_compare_uri(deployed_commit_id, latest_commit_id)}|#{deployed_commit_id}...#{latest_commit_id}>"
                end

        if value.present?
          fields << {
            title: 'Git compare',
            value: value,
            short: true
          }
        end

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          text: 'Begin deployment to ECS.',
          attachments: [
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            fields: fields,
            actions: [
              SUBMIT_APPROVE,
              SUBMIT_CANCEL
            ]
          ]
        )
      end

      def post_deploy_queue
        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: 'Deployment queue has been sent.',
          attachments: [{
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'Sidekiq',
              value: "#{ENV.fetch('GENOVA_URL')}/sidekiq",
              short: false
            }]
          }]
        )
      end

      def post_detect_auto_deploy(deploy_job)
        github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
        uri = github_client.build_branch_uri(deploy_job.branch)

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          attachments: [{
            text: 'GitHub deployment was detected.',
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'Repository',
              value: "<#{uri}|#{deploy_job.account}/#{deploy_job.repository}>",
              short: true
            }, {
              title: 'Branch',
              value: deploy_job.branch,
              short: true
            }]
          }]
        )
      end

      def post_detect_slack_deploy(deploy_job)
        github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
        repository_uri = github_client.build_repository_uri
        branch_uri = github_client.build_branch_uri(deploy_job.branch)

        fields = [{
          title: 'Repository',
          value: "<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>",
          short: true
        }, {
          title: 'Branch',
          value: "<#{branch_uri}|#{deploy_job.branch}>",
          short: true
        }, {
          title: 'Cluster',
          value: deploy_job.cluster,
          short: true
        }]

        if deploy_job.service.present?
          fields << {
            title: 'Service',
            value: deploy_job.service,
            short: true
          }
        elsif deploy_job.scheduled_task_rule.present?
          fields << {
            title: 'Scheduled task rule',
            value: deploy_job.scheduled_task_rule,
            short: true
          }
          fields << {
            title: 'Scheduled task target',
            value: deploy_job.scheduled_task_target,
            short: true
          }
        end

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: 'Slack deployment was detected.',
          attachments: [{
            color: Settings.slack.message.color.info,
            fields: fields
          }]
        )
      end

      def post_started_deploy(deploy_job, jid)
        url = "https://#{ENV.fetch('AWS_REGION')}.console.aws.amazon.com" \
              "/ecs/home?region=#{ENV.fetch('AWS_REGION')}#/clusters/#{deploy_job.cluster}/services/#{deploy_job.service}/tasks"

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: 'Deployment has started.',
          attachments: [{
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'ECS Console',
              value: url,
              short: false
            }, {
              title: 'Log',
              value: build_log_url(deploy_job.id),
              short: false
            }, {
              title: 'Sidekiq JID',
              value: jid,
              short: true
            }]
          }]
        )
      end

      def post_finished_deploy(deploy_job)
        fields = []

        if deploy_job.task_definition_arns[:service_task_definition_arn].present?
          fields << {
            title: 'New task definition ARN (Service)',
            value: escape_emoji(deploy_job.task_definition_arns[:service_task_definition_arn]),
            short: false
          }
        end

        if deploy_job.task_definition_arns[:scheduled_task_definition_arns].present?
          task_definition_arns = []

          deploy_job.task_definition_arns[:scheduled_task_definition_arns].each do |rule|
            rule[:targets_arns].each do |targets_arn|
              task_definition_arns << "(#{rule[:rule]}:#{targets_arn[:target]}) #{targets_arn[:task_definition_arn]}"
            end
          end

          fields << {
            title: 'New task definition ARN (Scheduled task)',
            value: escape_emoji(task_definition_arns.join("\n")),
            short: false
          }
        end

        if deploy_job.tag.present?
          github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
          fields << {
            title: 'GitHub tag',
            value: github_client.build_tag_uri(deploy_job.tag),
            short: false
          }
        end

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: "#{build_mension(deploy_job.slack_user_id)}\nDeployment is complete.",
          attachments: [{
            color: Settings.slack.message.color.info,
            fields: fields
          }]
        )
      end

      def post_error(params)
        fields = [{
          title: 'Name',
          value: escape_emoji(params[:error].class.to_s)
        }, {
          title: 'Message',
          value: escape_emoji(params[:error].message)
        }]

        if params[:error].backtrace.present?
          fields << {
            title: 'Backtrace',
            value: "```\n#{params[:error].backtrace.to_s.truncate(512)}```\n"
          }
        end

        if params.include?(:deploy_job_id)
          fields << {
            title: 'Deploy Job ID',
            value: params[:deploy_job_id]
          }
        end

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: build_mension(params[:slack_user_id]),
          attachments: [{
            text: 'Exception occurred.',
            color: Settings.slack.message.color.error,
            fields: fields
          }]
        )
      end

      private

      def build_mension(slack_user_id)
        slack_user_id.present? ? "<@#{slack_user_id}>" : nil
      end

      def build_log_url(deploy_job_id)
        "#{ENV.fetch('GENOVA_URL')}/logs/#{deploy_job_id}"
      end

      def escape_emoji(string)
        string.gsub(/:([\w]+):/, ":\u00AD\\1\u00AD:")
      end

      def git_latest_commit_id(params)
        repository_manager = Genova::Git::RepositoryManager.new(
          params[:account],
          params[:repository],
          params[:branch]
        )
        repository_manager.origin_last_commit_id.to_s
      end

      def git_deployed_commit_id(params)
        if params[:service].present?
          services = @ecs.describe_services(cluster: params[:cluster], services: [params[:service]]).services
          raise Genova::Error, "Service does not exist. [#{params[:service]}]" if services.size.zero?

          task_definition_arn = services[0].task_definition
        else
          cloudwatch_events_client = Aws::CloudWatchEvents::Client.new
          targets = cloudwatch_events_client.list_targets_by_rule(rule: params[:scheduled_task_rule])
          target = targets.targets.find do |k, _v|
            k.id == params[:scheduled_task_target]
          end

          task_definition_arn = target.ecs_parameters.task_definition_arn
        end

        task_definition = @ecs.describe_task_definition(task_definition: task_definition_arn)
        task_definitions = task_definition.task_definition.container_definitions

        deployed_commit_id = nil
        repository_manager = Genova::Git::RepositoryManager.new(params[:account], params[:repository])

        task_definitions.each do |task|
          matches = task[:image].match(/(build\-.*$)/)
          next if matches[1].nil?

          deployed_commit_id = repository_manager.find_commit_id(matches[1]).to_s
        end

        deployed_commit_id
      end
    end
  end
end
