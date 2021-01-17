module Genova
  module Slack
    module Interactive
      class Bot
        def initialize(params = {})
          @client = ::Slack::Web::Client.new(token: ENV.fetch('SLACK_API_TOKEN'))
          @parent_message_ts = params[:parent_message_ts]
          @logger = ::Logger.new(STDOUT, level: Settings.logger.level)
        end

        def send_message(text)
          send([BlockKit::Helper.section(text)])
        end

        def ask_history(params)
          options = BlockKit::ElementObject.history_options(params[:user])
          raise Genova::Exceptions::NotFoundError, 'History does not exist.' if options.size.zero?

          send([
                 BlockKit::Helper.section("<@#{params[:user]}> Please select history to deploy."),
                 BlockKit::Helper.actions([
                                          BlockKit::Helper.static_select('approve_deploy_from_history', options, 'Pick history...'),
                                          BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                        ])
               ])
        end

        def ask_repository(params)
          options = BlockKit::ElementObject.repository_options

          raise Genova::Exceptions::NotFoundError, 'Repositories is undefined.' if options.size.zero?

          send([
                 BlockKit::Helper.section("<@#{params[:user]}> Please select repository to deploy."),
                 BlockKit::Helper.actions([
                                          BlockKit::Helper.static_select('approve_repository', options, 'Pick repository...'),
                                          BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                        ])
               ])
        end

        def ask_branch(params)
          branch_options = BlockKit::ElementObject.branch_options(params[:account], params[:repository])
          tag_options = BlockKit::ElementObject.tag_options(params[:account], params[:repository])

          elements = []
          elements << BlockKit::Helper.static_select('approve_branch', branch_options, 'Pick branch...')
          elements << BlockKit::Helper.static_select('approve_tag', tag_options, 'Pick tag...') if tag_options.size.positive?
          elements << BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')

          send([
                 BlockKit::Helper.section('Please select branch to deploy.'),
                 BlockKit::Helper.actions(elements)
               ])
        end

        def ask_cluster(params)
          options = BlockKit::ElementObject.cluster_options(
            params[:account],
            params[:repository],
            params[:branch],
            params[:tag],
            params[:base_path]
          )
          raise Genova::Exceptions::NotFoundError, 'Clusters is undefined.' if options.size.zero?

          send([
                 BlockKit::Helper.section('Please select cluster to deploy.'),
                 BlockKit::Helper.actions([
                                          BlockKit::Helper.static_select('approve_cluster', options, 'Pick cluster...'),
                                          BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                        ])
               ])
        end

        def ask_target(params)
          option_groups = BlockKit::ElementObject.target_options(
            params[:account],
            params[:repository],
            params[:branch],
            params[:tag],
            params[:cluster],
            params[:base_path]
          )
          raise Genova::Exceptions::NotFoundError, 'Target is undefined.' if option_groups.size.zero?

          send([
                 BlockKit::Helper.section('Please select target to deploy.'),
                 BlockKit::Helper.actions([
                                          BlockKit::Helper.static_select('approve_target', option_groups, 'Pick target...', group: true),
                                          BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                        ])
               ])
        end

        def ask_confirm_deploy(params, show_target, mention = false)
          confirm_command(params, mention) if show_target

          send([
                 BlockKit::Helper.section("Ready to deploy!"),
                 BlockKit::Helper.section_short_fieldset([git_compare(params)]),
                 BlockKit::Helper.actions([
                                          BlockKit::Helper.primary_button('Deploy', 'deploy', 'approve_deploy'),
                                          BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                        ])
               ])
        end

        def detect_github_event(deploy_job)
          github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
          repository_uri = github_client.build_repository_uri
          branch_uri = github_client.build_branch_uri(deploy_job.branch)

          send([
                 BlockKit::Helper.header('GitHub deployment was detected.'),
                 BlockKit::Helper.section_short_fieldset(
                   [
                     BlockKit::Helper.section_short_field('Repository', "<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>"),
                     BlockKit::Helper.section_short_field('Branch', "<#{branch_uri}|#{deploy_job.branch}>")
                   ]
                 )
               ])
        end

        def detect_slack_deploy(deploy_job, jid)
          github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
          repository_uri = github_client.build_repository_uri
          branch_uri = github_client.build_branch_uri(deploy_job.branch)

          fields = []
          fields << BlockKit::Helper.section_short_field('Repository', "<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>")

          fields << if deploy_job.branch.present?
                      BlockKit::Helper.section_short_field('Branch', "<#{branch_uri}|#{deploy_job.branch}>")
                    else
                      BlockKit::Helper.section_short_field('Tag', deploy_job.tag)
                    end

          fields << BlockKit::Helper.section_short_field('Cluster', deploy_job.cluster)

          if deploy_job.service.present?
            fields << BlockKit::Helper.section_short_field('Service', deploy_job.service)
          elsif deploy_job.scheduled_task_rule.present?
            fields << BlockKit::Helper.section_short_field('Scheduled task rule', deploy_job.scheduled_task_rule)
            fields << BlockKit::Helper.section_short_field('Scheduled task target', deploy_job.scheduled_task_target)
          end

          console_uri = "https://#{ENV.fetch('AWS_REGION')}.console.aws.amazon.com/ecs/home" \
                        "?region=#{ENV.fetch('AWS_REGION')}#/clusters/#{deploy_job.cluster}/services/#{deploy_job.service}/tasks"

          send([
                 BlockKit::Helper.header('Start deploy job.'),
                 BlockKit::Helper.section_short_fieldset(fields),
                 BlockKit::Helper.divider,
                 BlockKit::Helper.section_short_fieldset(
                   [
                     BlockKit::Helper.section_short_field('AWS Console', console_uri),
                     BlockKit::Helper.section_short_field('Deploy log', "#{ENV.fetch('GENOVA_URL')}/deploy_jobs/#{deploy_job.id}"),
                     BlockKit::Helper.section_short_field('Sidekiq', jid.to_s)
                   ]
                 )
               ])
        end

        def finished_deploy(deploy_job)
          fields = []
          fields << BlockKit::Helper.section_field('New task definition ARN', deploy_job.task_definition_arns.join("\n"))

          if deploy_job.tag.present?
            github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
            fields << BlockKit::Helper.section_field('Tag', "<#{github_client.build_tag_uri(deploy_job.tag)}|#{deploy_job.tag}>")
          end

          send([
                 BlockKit::Helper.header('Deployment is complete.'),
                 BlockKit::Helper.section("<@#{deploy_job.slack_user_id}>"),
                 BlockKit::Helper.section_fieldset(fields)
               ])
        end

        def error(params)
          fields = []
          fields << BlockKit::Helper.section_field('Error', params[:error].class)
          fields << BlockKit::Helper.section_field('Reason', params[:error].message)
          fields << BlockKit::Helper.section_field('Backtrace', "```#{params[:error].backtrace.join("\n").truncate(512)}```") if params[:error].backtrace.present?
          fields << BlockKit::Helper.section_field('Deploy job ID', params[:deploy_job_id]) if params[:deploy_job_id].present?

          send([
                 BlockKit::Helper.header('Oops! Runtime error has occurred.'),
                 BlockKit::Helper.section_fieldset(fields)
               ])
        end

        private

        def confirm_command(params, mention)
          github_client = Genova::Github::Client.new(params[:account], params[:repository])

          fields = []
          fields << BlockKit::Helper.section_short_field('Repository', "<#{github_client.build_repository_uri}|#{params[:account]}/#{params[:repository]}>")

          fields << if params[:branch].present?
                      BlockKit::Helper.section_short_field('Branch', "<#{github_client.build_branch_uri(params[:branch])}|#{params[:branch]}>")
                    else
                      BlockKit::Helper.section_short_field('Tag', "<#{github_client.build_tag_uri(params[:tag])}|#{params[:tag]}>")
                    end

          fields << BlockKit::Helper.section_short_field('Cluster', params[:cluster])

          case params[:type]
          when DeployJob.type.find_value(:run_task)
            fields << BlockKit::Helper.section_short_field('Run task', params[:run_task])

          when DeployJob.type.find_value(:service)
            fields << BlockKit::Helper.section_short_field('Service', params[:service])

          when DeployJob.type.find_value(:scheduled_task)
            fields << BlockKit::Helper.section_short_field('Scheduled task rule', params[:scheduled_task_rule])
            fields << BlockKit::Helper.section_short_field('Scheduled task target', params[:scheduled_task_target])
          end

          text = mention ? "<@#{params[:user]}> " : ''

          send([
            BlockKit::Helper.section("#{text}Please confirm."),
            BlockKit::Helper.section_short_fieldset(fields)
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

          BlockKit::Helper.section_short_field('Git compare', text)
        end
      end
    end
  end
end
