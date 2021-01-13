module Genova
  module Slack
    class Bot
      def initialize(client = nil)
        @client = client || ::Slack::Web::Client.new(token: ENV.fetch('SLACK_API_TOKEN'))
      end

      def post_simple_message(params)
        send([BlockKitHelper.section(params[:text])])
      end

      def post_choose_history(params)
        options = BlockKitElementObject.history_options(params[:user])
        raise Genova::Exceptions::NotFoundError, 'History does not exist.' if options.size.zero?

        send([
          BlockKitHelper.section('Please specify job to be redeployed.'),
          BlockKitHelper.actions([
            BlockKitHelper.static_select('approve_deploy_from_history', options, 'Pick history...'),
            BlockKitHelper.cancel_button
          ])
        ])
      end

      def post_choose_repository
        options = BlockKitElementObject.repository_options

        raise Genova::Exceptions::NotFoundError, 'Repositories is undefined.' if options.size.zero?

        send([
          BlockKitHelper.section('Deploy repository.'),
          BlockKitHelper.actions([
            BlockKitHelper.static_select('approve_repository', options, 'Pick repository...'),
            BlockKitHelper.cancel_button
          ])
        ])
      end

      def post_choose_branch(params)
        branch_options = BlockKitElementObject.branch_options(params[:account], params[:repository])
        tag_options = BlockKitElementObject.tag_options(params[:account], params[:repository])

        elements = []
        elements << BlockKitHelper.static_select('approve_branch', branch_options, 'Pick branch...')
        elements << BlockKitHelper.static_select('approve_tag', tag_options, 'Pick tag...') if tag_options.size.positive?
        elements << BlockKitHelper.cancel_button

        send([
          BlockKitHelper.section('Deploy branch.'),
          BlockKitHelper.actions(elements)
        ])
      end

      def post_choose_cluster(params)
        options = BlockKitElementObject.cluster_options(
          params[:account],
          params[:repository],
          params[:branch],
          params[:tag],
          params[:base_path]
        )
        raise Genova::Exceptions::NotFoundError, 'Clusters is undefined.' if options.size.zero?

        send([
          BlockKitHelper.section('Deploy cluster.'),
          BlockKitHelper.actions([
            BlockKitHelper.static_select('approve_cluster', options, 'Pick cluster...'),
            BlockKitHelper.cancel_button
          ])
        ])
      end

      def post_choose_target(params)
        option_groups = BlockKitElementObject.target_options(
          params[:account],
          params[:repository],
          params[:branch],
          params[:tag],
          params[:cluster],
          params[:base_path]
        )
        raise Genova::Exceptions::NotFoundError, 'Target is undefined.' if option_groups.size.zero?

        send([
          BlockKitHelper.section('Deploy target.'),
          BlockKitHelper.actions([
            BlockKitHelper.static_select('approve_target', option_groups, 'Pick target...', group: true),
            BlockKitHelper.cancel_button
          ])
        ])
      end

      def post_confirm_deploy(params, show_target = true)
        post_confirm_command(params) if show_target

        send([
          BlockKitHelper.section('Begin deployment to ECS.'),
          BlockKitHelper.section_short_fieldset([git_compare(params)]),
          BlockKitHelper.actions([
            BlockKitHelper.approve_button('approve_deploy'),
            BlockKitHelper.cancel_button
          ])
        ])
      end

      def post_detect_auto_deploy(deploy_job)
        github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
        repository_uri = github_client.build_repository_uri
        branch_uri = github_client.build_branch_uri(deploy_job.branch)

        send([
          BlockKitHelper.header('GitHub deployment was detected.'),
          BlockKitHelper.section_short_fieldset(
            [
              BlockKitHelper.section_short_field('Repository', "<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>"),
              BlockKitHelper.section_short_field('Branch', "<#{branch_uri}|#{deploy_job.branch}>")
            ]
          )
        ])
      end

      def post_detect_slack_deploy(deploy_job, jid)
        github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
        repository_uri = github_client.build_repository_uri
        branch_uri = github_client.build_branch_uri(deploy_job.branch)

        fields = []
        fields << BlockKitHelper.section_short_field('Repository', "<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>")

        if deploy_job.branch.present?
          fields << BlockKitHelper.section_short_field('Branch', "<#{branch_uri}|#{deploy_job.branch}>")
        else
          fields << BlockKitHelper.section_short_field('Tag', deploy_job.tag)
        end

        fields << BlockKitHelper.section_short_field('Cluster', deploy_job.cluster)

        if deploy_job.service.present?
          fields << BlockKitHelper.section_short_field('Service', deploy_job.service)
        elsif deploy_job.scheduled_task_rule.present?
          fields << BlockKitHelper.section_short_field('Scheduled task rule', deploy_job.scheduled_task_rule)
          fields << BlockKitHelper.section_short_field('Scheduled task target', deploy_job.scheduled_task_target)
        end

        console_uri = "https://#{ENV.fetch('AWS_REGION')}.console.aws.amazon.com/ecs/home" +
                     "?region=#{ENV.fetch('AWS_REGION')}#/clusters/#{deploy_job.cluster}/services/#{deploy_job.service}/tasks"

        send([
          BlockKitHelper.header('Slack deployment was detected.'),
          BlockKitHelper.section_short_fieldset(fields),
          BlockKitHelper.divider,
          BlockKitHelper.section_short_fieldset(
            [
              BlockKitHelper.section_short_field('ECS Console', console_uri),
              BlockKitHelper.section_short_field('Log', build_log_url(deploy_job.id)),
              BlockKitHelper.section_short_field('Sidekiq', "#{jid}")
            ]
          )
        ])
      end

      def post_finished_deploy(deploy_job)
        fields = []
        fields << BlockKitHelper.section_short_field('New task definition ARN', escape_emoji(deploy_job.task_definition_arns.join("\n")))

        if deploy_job.tag.present?
          github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
          fields << BlockKitHelper.section_short_field('GitHub tag', github_client.build_tag_uri(deploy_job.tag))
        end

        send([
          BlockKitHelper.header('Deployment is complete.'),
          BlockKitHelper.section(build_mension(deploy_job.slack_user_id)),
          BlockKitHelper.section_short_fieldset(fields)
        ])
      end

      def post_error(params)
        fields = []
        fields << BlockKitHelper.section_field('Error', params[:error].class)
        fields << BlockKitHelper.section_field('Reason', escape_emoji(params[:error].message))
        fields << BlockKitHelper.section_field('Backtrace', "```#{params[:error].backtrace.to_s.truncate(512)}```") if params[:error].backtrace.present?
        fields << BlockKitHelper.section_field('Deploy Job ID', params[:deploy_job_id]) if params[:dieploy_job_id].present?

        send([
          BlockKitHelper.header('Oops! Runtime error has occurred.'),
          BlockKitHelper.section_fieldset(fields)
        ])
      end

      private

      def send(blocks)
        data = {
          channel: ENV.fetch('SLACK_CHANNEL'),
          blocks: blocks
        }
        @client.chat_postMessage(data)
      end

      def post_confirm_command(params)
        fields = []
        fields << BlockKitHelper.section_short_field('Repository', params[:repository])

        if params[:branch].present?
          fields << BlockKitHelper.section_short_field('Branch', params[:branch])
        else
          fields << BlockKitHelper.section_short_field('Tag', params[:tag])
        end

        fields << BlockKitHelper.section_short_field('Cluster', params[:cluster])

        case params[:type]
        when DeployJob.type.find_value(:run_task)
          fields << BlockKitHelper.section_short_field('Run task', params[:run_task])

        when DeployJob.type.find_value(:service)
          fields << BlockKitHelper.section_short_field('Service', params[:service])

        when DeployJob.type.find_value(:scheduled_task)
          fields << BlockKitHelper.section_short_field('Scheduled task rule', params[:scheduled_task_rule])
          fields << BlockKitHelper.section_short_field('Scheduled task target', params[:scheduled_task_target])
        end

        send([BlockKitHelper.section_short_fieldset(fields)])
      end

      def git_compare(params)
        if params[:run_task].present?
          text = 'Run task diff is not yet supported.'
        else
          latest_commit_id = git_latest_commit_id(params)
          deployed_commit_id = git_deployed_commit_id(params)

          if latest_commit_id == deployed_commit_id
            text = 'Commit ID is unchanged.'
          elsif deployed_commit_id.present?
            github_client = Genova::Github::Client.new(params[:account], params[:repository])
            uri = github_client.build_compare_uri(deployed_commit_id, latest_commit_id).to_s
            text = uri
          else
            text = 'Unknown.'
          end
        end

        BlockKitHelper.section_short_field('Git compare', text)
      end

      def build_mension(slack_user_id)
        slack_user_id.present? ? "<@#{slack_user_id}>" : nil
      end

      def build_log_url(deploy_job_id)
        "#{ENV.fetch('GENOVA_URL')}/deploy_jobs/#{deploy_job_id}"
      end

      def escape_emoji(string)
        string.gsub(/:([\w]+):/, ":\u00AD\\1\u00AD:")
      end

      def git_latest_commit_id(params)
        code_manager = Genova::CodeManager::Git.new(
          params[:account],
          params[:repository],
          branch: params[:branch],
          tag: params[:tag]
        )
        code_manager.origin_last_commit_id.to_s
      end

      def git_deployed_commit_id(params)
        ecs = Aws::ECS::Client.new

        if params[:service].present?
          services = ecs.describe_services(cluster: params[:cluster], services: [params[:service]]).services
          raise Exceptions::NotFoundError, "Service does not exist. [#{params[:service]}]" if services.size.zero?

          task_definition_arn = services[0].task_definition
        else
          cloudwatch_events_client = Aws::CloudWatchEvents::Client.new
          targets = cloudwatch_events_client.list_targets_by_rule(rule: params[:scheduled_task_rule])
          target = targets.targets.find do |k, _v|
            k.id == params[:scheduled_task_target]
          end

          task_definition_arn = target.ecs_parameters.task_definition_arn
        end

        task_definition = ecs.describe_task_definition(task_definition: task_definition_arn)
        task_definitions = task_definition.task_definition.container_definitions

        deployed_commit_id = nil
        code_manager = Genova::CodeManager::Git.new(params[:account], params[:repository])

        task_definitions.each do |task|
          matches = task[:image].match(/(build\-.*$)/)
          next if matches.nil?

          deployed_commit_id = code_manager.find_commit_id(matches[1]).to_s
        end

        deployed_commit_id
      end
    end
  end
end
