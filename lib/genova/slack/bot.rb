module Genova
  module Slack
    class Bot
      def initialize(params = {})
        @client = ::Slack::Web::Client.new(token: ENV.fetch('SLACK_API_TOKEN'))
        @parent_message_ts = params[:parent_message_ts]
        @logger = ::Logger.new(STDOUT, level: Settings.logger.level)
      end

      def post_simple_message(params)
        send([BlockKitHelper.section(params[:text])])
      end

      def post_choose_history(params)
        options = BlockKitElementObject.history_options(params[:user])
        raise Genova::Exceptions::NotFoundError, 'History does not exist.' if options.size.zero?

        send([
               BlockKitHelper.section("<@#{params[:user]}> Please select history to deploy."),
               BlockKitHelper.actions([
                                        BlockKitHelper.static_select('approve_deploy_from_history', options, 'Pick history...'),
                                        BlockKitHelper.cancel_button('Cancel', 'cancel', 'cancel')
                                      ])
             ])
      end

      def post_choose_repository(params)
        options = BlockKitElementObject.repository_options

        raise Genova::Exceptions::NotFoundError, 'Repositories is undefined.' if options.size.zero?

        send([
               BlockKitHelper.section("<@#{params[:user]}> Please select repository to deploy."),
               BlockKitHelper.actions([
                                        BlockKitHelper.static_select('approve_repository', options, 'Pick repository...'),
                                        BlockKitHelper.cancel_button('Cancel', 'cancel', 'cancel')
                                      ])
             ])
      end

      def post_choose_branch(params)
        branch_options = BlockKitElementObject.branch_options(params[:account], params[:repository])
        tag_options = BlockKitElementObject.tag_options(params[:account], params[:repository])

        elements = []
        elements << BlockKitHelper.static_select('approve_branch', branch_options, 'Pick branch...')
        elements << BlockKitHelper.static_select('approve_tag', tag_options, 'Pick tag...') if tag_options.size.positive?
        elements << BlockKitHelper.cancel_button('Cancel', 'cancel', 'cancel')

        send([
               BlockKitHelper.section('Please select branch to deploy.'),
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
               BlockKitHelper.section('Please select cluster to deploy.'),
               BlockKitHelper.actions([
                                        BlockKitHelper.static_select('approve_cluster', options, 'Pick cluster...'),
                                        BlockKitHelper.cancel_button('Cancel', 'cancel', 'cancel')
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
               BlockKitHelper.section('Please select target to deploy.'),
               BlockKitHelper.actions([
                                        BlockKitHelper.static_select('approve_target', option_groups, 'Pick target...', group: true),
                                        BlockKitHelper.cancel_button('Cancel', 'cancel', 'cancel')
                                      ])
             ])
      end

      def post_confirm_deploy(params, show_target, mention = false)
        post_confirm_command(params, mention) if show_target

        send([
               BlockKitHelper.section("Ready to deploy!"),
               BlockKitHelper.section_short_fieldset([git_compare(params)]),
               BlockKitHelper.actions([
                                        BlockKitHelper.primary_button('Deploy', 'deploy', 'approve_deploy'),
                                        BlockKitHelper.cancel_button('Cancel', 'cancel', 'cancel')
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

        fields << if deploy_job.branch.present?
                    BlockKitHelper.section_short_field('Branch', "<#{branch_uri}|#{deploy_job.branch}>")
                  else
                    BlockKitHelper.section_short_field('Tag', deploy_job.tag)
                  end

        fields << BlockKitHelper.section_short_field('Cluster', deploy_job.cluster)

        if deploy_job.service.present?
          fields << BlockKitHelper.section_short_field('Service', deploy_job.service)
        elsif deploy_job.scheduled_task_rule.present?
          fields << BlockKitHelper.section_short_field('Scheduled task rule', deploy_job.scheduled_task_rule)
          fields << BlockKitHelper.section_short_field('Scheduled task target', deploy_job.scheduled_task_target)
        end

        console_uri = "https://#{ENV.fetch('AWS_REGION')}.console.aws.amazon.com/ecs/home" \
                      "?region=#{ENV.fetch('AWS_REGION')}#/clusters/#{deploy_job.cluster}/services/#{deploy_job.service}/tasks"

        send([
               BlockKitHelper.header('Start deploy job.'),
               BlockKitHelper.section_short_fieldset(fields),
               BlockKitHelper.divider,
               BlockKitHelper.section_short_fieldset(
                 [
                   BlockKitHelper.section_short_field('AWS Console', console_uri),
                   BlockKitHelper.section_short_field('Deploy log', "#{ENV.fetch('GENOVA_URL')}/deploy_jobs/#{deploy_job.id}"),
                   BlockKitHelper.section_short_field('Sidekiq', jid.to_s)
                 ]
               )
             ])
      end

      def post_finished_deploy(deploy_job)
        fields = []
        fields << BlockKitHelper.section_field('New task definition ARN', deploy_job.task_definition_arns.join("\n"))

        if deploy_job.tag.present?
          github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
          fields << BlockKitHelper.section_field('Tag', "<#{github_client.build_tag_uri(deploy_job.tag)}|#{deploy_job.tag}>")
        end

        send([
               BlockKitHelper.header('Deployment is complete.'),
               BlockKitHelper.section("<@#{deploy_job.slack_user_id}>"),
               BlockKitHelper.section_fieldset(fields)
             ])
      end

      def post_error(params)
        fields = []
        fields << BlockKitHelper.section_field('Error', params[:error].class)
        fields << BlockKitHelper.section_field('Reason', params[:error].message)
        fields << BlockKitHelper.section_field('Backtrace', "```#{params[:error].backtrace.join("\n").truncate(512)}```") if params[:error].backtrace.present?
        fields << BlockKitHelper.section_field('Deploy job ID', params[:deploy_job_id]) if params[:deploy_job_id].present?

        send([
               BlockKitHelper.header('Oops! Runtime error has occurred.'),
               BlockKitHelper.section_fieldset(fields)
             ])
      end

      private

      def post_confirm_command(params, mention)
        github_client = Genova::Github::Client.new(params[:account], params[:repository])

        fields = []
        fields << BlockKitHelper.section_short_field('Repository', "<#{github_client.build_repository_uri}|#{params[:account]}/#{params[:repository]}>")

        fields << if params[:branch].present?
                    BlockKitHelper.section_short_field('Branch', "<#{github_client.build_branch_uri(params[:branch])}|#{params[:branch]}>")
                  else
                    BlockKitHelper.section_short_field('Tag', "<#{github_client.build_tag_uri(params[:tag])}|#{params[:tag]}>")
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

        text = mention ? "<@#{params[:user]}> " : ''

        send([
          BlockKitHelper.section("#{text}Please confirm."),
          BlockKitHelper.section_short_fieldset(fields)
        ])
      end

      def send(blocks)
        data = {
          channel: ENV.fetch('SLACK_CHANNEL'),
          blocks: blocks
        }
        data[:thread_ts] = @parent_message_ts if Settings.slack.thread_conversion

        @logger.info(data.to_json)
        @client.chat_postMessage(data)
      end

      def git_compare(params)
        if params[:run_task].present?
          text = 'Run task diff is not yet supported.'
        else
          code_manager = Genova::CodeManager::Git.new(
            params[:account],
            params[:repository],
            branch: params[:branch],
            tag: params[:tag]
          )

          last_commit = code_manager.origin_last_commit
          ecs_client = Aws::ECS::Client.new

          if params[:service].present?
            services = ecs_client.describe_services(cluster: params[:cluster], services: [params[:service]]).services
            raise Exceptions::NotFoundError, "Service does not exist. [#{params[:service]}]" if services.size.zero?

            task_definition_arn = services[0].task_definition
          else
            cloudwatch_events_client = Aws::CloudWatchEvents::Client.new
            rules = cloudwatch_events_client.list_rules(name_prefix: params[:scheduled_task_rule])
            raise Exceptions::NotFoundError, "Scheduled task rule does not exist. [#{params[:scheduled_task_rule]}]" if rules[:rules].size.zero?

            targets = cloudwatch_events_client.list_targets_by_rule(rule: rules[:rules][0].name)
            target = targets.targets.find { |v| v.id == params[:scheduled_task_target] }
            raise Exceptions::NotFoundError, "Scheduled task target does not exist. [#{params[:scheduled_task_target]}]" if target.nil?

            task_definition_arn = target.ecs_parameters.task_definition_arn
          end

          task_definition = ecs_client.describe_task_definition(task_definition: task_definition_arn, include: ['TAGS'])

          build = task_definition[:tags].find { |v| v[:key] == 'genova.build' }

          if build.present?
            deployed_commit = code_manager.find_commit(build[:value])

            if last_commit == deployed_commit
              text = 'Unchanged.'
            else
              github_client = Genova::Github::Client.new(params[:account], params[:repository])
              text = github_client.build_compare_uri(deployed_commit, last_commit)
            end
          else
            text = 'Unknown'
          end
        end

        BlockKitHelper.section_short_field('Git compare', text)
      end
    end
  end
end
