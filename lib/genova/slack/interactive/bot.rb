module Genova
  module Slack
    module Interactive
      class Bot
        def initialize(params = {})
          @client = ::Slack::Web::Client.new(token: Settings.slack.api_token)
          @parent_message_ts = params[:parent_message_ts]
          @logger = ::Logger.new($stdout, level: Settings.logger.level)
        end

        def send_message(text)
          send([BlockKit::Helper.section(text)])
        end

        def ask_history(params)
          options = BlockKit::ElementObject.history_options(user: params[:user])
          raise Genova::Exceptions::NotFoundError, 'History does not exist.' if options.size.zero?

          send([
                 BlockKit::Helper.section("<@#{params[:user]}> Please select history to deploy."),
                 BlockKit::Helper.actions([
                                            BlockKit::Helper.radio_buttons('approve_deploy_from_history', options),
                                            BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                          ])
               ])
        end

        def ask_repository(params)
          repositoriy_options = BlockKit::ElementObject.repository_options(params)
          workflow_options = BlockKit::ElementObject.workflow_options(params)

          raise Genova::Exceptions::NotFoundError, 'Repositories is undefined.' if repositoriy_options.size.zero?

          blocks = []
          blocks << BlockKit::Helper.section("<@#{params[:user]}> Specify the repository or workflow to deploy.")
          blocks << BlockKit::Helper.static_select('approve_repository', 'Repository', repositoriy_options)
          blocks << BlockKit::Helper.static_select('approve_workflow', 'Workflow', workflow_options) if workflow_options.size.positive?

          blocks << BlockKit::Helper.section(' ')
          blocks << BlockKit::Helper.divider

          actions = [BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')]
          blocks << BlockKit::Helper.actions(actions)

          send(blocks)
        end

        def ask_branch(params)
          branch_options = BlockKit::ElementObject.branch_options(repository: params[:repository])
          tag_options = BlockKit::ElementObject.tag_options(repository: params[:repository])

          blocks = []
          blocks << BlockKit::Helper.section('Specify a branch or tag.')
          blocks << BlockKit::Helper.static_select('approve_branch', 'Branch', branch_options)
          blocks << BlockKit::Helper.static_select('approve_tag', 'Tag', tag_options) if tag_options.size.positive?

          blocks << BlockKit::Helper.section(' ')
          blocks << BlockKit::Helper.divider

          actions = [BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')]
          blocks << BlockKit::Helper.actions(actions)

          send(blocks)
        end

        def ask_cluster(params)
          options = BlockKit::ElementObject.cluster_options(params)
          raise Genova::Exceptions::NotFoundError, 'No deployable clusters found.' if options.size.zero?

          blocks = []
          blocks << BlockKit::Helper.section('Specify cluster.')
          blocks << BlockKit::Helper.static_select('approve_cluster', 'Cluster', options)

          blocks << BlockKit::Helper.section(' ')
          blocks << BlockKit::Helper.divider

          actions = [BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')]
          blocks << BlockKit::Helper.actions(actions)

          send(blocks)
        end

        def ask_target(params)
          run_task_options = BlockKit::ElementObject.run_task_options(params)
          service_options = BlockKit::ElementObject.service_options(params)
          scheduled_task_options = BlockKit::ElementObject.scheduled_task_options(params)

          raise Genova::Exceptions::NotFoundError, 'Target is undefined.' if run_task_options.size.zero? && service_options.size.zero? && scheduled_task_options.size.zero?

          blocks = []
          blocks << BlockKit::Helper.section('Specify resources to deploy.')

          if service_options.size.positive?
            blocks << BlockKit::Helper.static_select('approve_service', 'Service', service_options)
            blocks << BlockKit::Helper.section(' ')
            blocks << BlockKit::Helper.divider
          end

          if scheduled_task_options.size.positive?
            blocks << BlockKit::Helper.static_select('approve_scheduled_task', 'Scheduled task', scheduled_task_options)
            blocks << BlockKit::Helper.section(' ')
            blocks << BlockKit::Helper.divider
          end

          if run_task_options.size.positive?
            blocks << BlockKit::Helper.static_select('approve_run_task', 'Run task', run_task_options)
            blocks << BlockKit::Helper.section('The command to be executed in Run task can be overridden (Optional).')
            blocks << BlockKit::Helper.plain_text_input('submit_run_task_override_container', 'Override container', placeholder: 'Input container', block_id: 'run_task_override_container')
            blocks << BlockKit::Helper.plain_text_input('submit_run_task_override_command', 'Override command', placeholder: 'Input command', block_id: 'run_task_override_command')
            blocks << BlockKit::Helper.section(' ')
            blocks << BlockKit::Helper.actions([BlockKit::Helper.primary_button('Next', 'next', 'submit_run_task')])
            blocks << BlockKit::Helper.divider
          end

          actions = [BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')]
          blocks << BlockKit::Helper.actions(actions)

          send(blocks)
        end

        def ask_confirm_deploy(params, show_target: true, mention: false)
          confirm_command(params, mention) if show_target

          blocks = []
          blocks << BlockKit::Helper.section('Ready to deploy!')
          blocks << BlockKit::Helper.section_short_fieldset([git_compare(params)]) unless params[:type] == DeployJob.type.find_value(:run_task)
          blocks << BlockKit::Helper.actions([
                                               BlockKit::Helper.primary_button('Deploy', 'deploy', 'approve_deploy'),
                                               BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                             ])

          send(blocks)
        end

        def ask_confirm_workflow_deploy(params)
          blocks = []
          blocks << BlockKit::Helper.section('Ready to deploy!')

          steps = Settings.workflows.find { |k| k[:name] == params[:name] }[:steps]
          steps.each.with_index(1) do |step, i|
            blocks << BlockKit::Helper.header("Step ##{i}")
            blocks << BlockKit::Helper.section_short_fieldset(
              [
                BlockKit::Helper.section_short_field('Repository', step[:repository]),
                BlockKit::Helper.section_short_field('Branch', step[:branch]),
                BlockKit::Helper.section_short_field('Cluster', step[:cluster]),
                BlockKit::Helper.section_short_field('Type', step[:type]),
                BlockKit::Helper.section_short_field('Resources', step[:resources].join(', '))
              ]
            )
          end

          blocks << BlockKit::Helper.actions([
                                               BlockKit::Helper.primary_button('Deploy', 'deploy', 'approve_workflow_deploy'),
                                               BlockKit::Helper.cancel_button('Cancel', 'cancel', 'cancel')
                                             ])

          send(blocks)
        end

        def complete_deploy(params)
          fields = []
          fields << BlockKit::Helper.section_field('Task definition ARN', code(BlockKit::Helper.escape_emoji(params[:deploy_job].task_definition_arn)))
          fields << BlockKit::Helper.section_field('Task ARNs', code(BlockKit::Helper.escape_emoji(params[:deploy_job].task_arns.join("\n")))) if params[:deploy_job].task_arns.present?

          if params[:deploy_job].tag.present?
            github_client = Genova::Github::Client.new(params[:deploy_job].repository)
            fields << BlockKit::Helper.section_field('Tag', "<#{github_client.build_tag_uri(params[:deploy_job].tag)}|#{params[:deploy_job].tag}>")
          end

          blocks = []
          blocks << BlockKit::Helper.section("<@#{params[:deploy_job].slack_user_id}>") if params[:deploy_job].mode == DeployJob.mode.find_value(:slack)
          blocks << BlockKit::Helper.section('Deployment was successful.')
          blocks << BlockKit::Helper.section_fieldset(fields)

          send(blocks)
        end

        def detect_auto_deploy(params)
          github_client = Genova::Github::Client.new(params[:repository])
          repository_uri = github_client.build_repository_uri
          branch_uri = github_client.build_branch_uri(params[:branch])

          send([
                 BlockKit::Helper.header('Detect auto deploy.'),
                 BlockKit::Helper.section_short_fieldset(
                   [
                     BlockKit::Helper.section_short_field('Repository', "<#{repository_uri}|#{Settings.github.account}/#{params[:repository]}>"),
                     BlockKit::Helper.section_short_field('Branch', "<#{branch_uri}|#{params[:branch]}>"),
                     BlockKit::Helper.section_short_field('Commit URL', params[:commit_url]),
                     BlockKit::Helper.section_short_field('Author', params[:author])
                   ]
                 )
               ])
        end

        def detect_slack_deploy(params)
          github_client = Genova::Github::Client.new(params[:deploy_job].repository)
          repository_uri = github_client.build_repository_uri
          branch_uri = github_client.build_branch_uri(params[:deploy_job].branch)

          fields = []
          fields << BlockKit::Helper.section_short_field('Repository', "<#{repository_uri}|#{params[:deploy_job].account}/#{params[:deploy_job].repository}>")

          fields << if params[:deploy_job].branch.present?
                      BlockKit::Helper.section_short_field('Branch', "<#{branch_uri}|#{params[:deploy_job].branch}>")
                    else
                      BlockKit::Helper.section_short_field('Tag', params[:deploy_job].tag)
                    end

          fields << BlockKit::Helper.section_short_field('Cluster', params[:deploy_job].cluster)

          if params[:deploy_job].service.present?
            fields << BlockKit::Helper.section_short_field('Service', params[:deploy_job].service)
          elsif params[:deploy_job].scheduled_task_rule.present?
            fields << BlockKit::Helper.section_short_field('Scheduled task rule', params[:deploy_job].scheduled_task_rule)
            fields << BlockKit::Helper.section_short_field('Scheduled task target', params[:deploy_job].scheduled_task_target)
          end

          console_uri = "https://#{ENV.fetch('AWS_REGION')}.console.aws.amazon.com/ecs/home" \
                        "?region=#{ENV.fetch('AWS_REGION')}#/clusters/#{params[:deploy_job].cluster}/services/#{params[:deploy_job].service}/tasks"

          send([
                 BlockKit::Helper.header('Start deploy job.'),
                 BlockKit::Helper.section_short_fieldset(fields),
                 BlockKit::Helper.divider,
                 BlockKit::Helper.section_short_fieldset(
                   [
                     BlockKit::Helper.section_short_field('AWS Console', console_uri),
                     BlockKit::Helper.section_short_field('Deploy log', "#{Settings.console.url}/deploy_jobs/#{params[:deploy_job].id}")
                   ]
                 )
               ])
        end

        def start_step(params)
          send([
                 BlockKit::Helper.header("Start deployment Step ##{params[:index]}.")
               ])
        end

        def start_deploy(params)
          fields = []
          fields << BlockKit::Helper.section_short_field('Cluster', params[:deploy_job].cluster)
          fields << BlockKit::Helper.section_short_field('Service', params[:deploy_job].service) if params[:deploy_job].type == DeployJob.type.find_value(:service)
          fields << BlockKit::Helper.section_short_field('Run task', params[:deploy_job].run_task) if params[:deploy_job].type == DeployJob.type.find_value(:run_task)
          fields << BlockKit::Helper.section_short_field('Deploy log', "#{Settings.console.url}/deploy_jobs/#{params[:deploy_job].id}")

          send([
                 BlockKit::Helper.section('Start deployment.'),
                 BlockKit::Helper.section_short_fieldset(fields)
               ])
        end

        def complete_steps(params)
          mention = params[:user].present? ? "<@#{params[:user]}>" : '<!channel>'

          send([
                 BlockKit::Helper.section(mention),
                 BlockKit::Helper.section('All deployments are complete.')
               ])
        end

        def error(params)
          fields = []
          fields << BlockKit::Helper.section_field('Error', BlockKit::Helper.escape_emoji(params[:error].class.to_s))
          fields << BlockKit::Helper.section_field('Reason', code(BlockKit::Helper.escape_emoji(params[:error].message)))
          fields << BlockKit::Helper.section_field('Backtrace', code(params[:error].backtrace.join("\n").truncate(512))) if params[:error].backtrace.present?

          blocks = []
          blocks << BlockKit::Helper.section("<@#{params[:user]}>") if params[:user].present?
          blocks << BlockKit::Helper.header('Oops! Runtime error has occurred.')
          blocks << BlockKit::Helper.section_fieldset(fields)

          send(blocks)
        end

        private

        def code(string)
          "```#{string.truncate(512)}```"
        end

        def confirm_command(params, mention)
          github_client = Genova::Github::Client.new(params[:repository])

          fields = []
          fields << BlockKit::Helper.section_short_field('Repository', "<#{github_client.build_repository_uri}|#{Settings.github.account}/#{params[:repository]}>")

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
            channel: Settings.slack.channel,
            blocks: blocks,
            thread_ts: @parent_message_ts
          }

          @logger.info(data.to_json)
          @client.chat_postMessage(data)
        end

        def running_task_definition(params)
          ecs_client = Aws::ECS::Client.new

          if params[:service].present?
            services = ecs_client.describe_services(cluster: params[:cluster], services: [params[:service]]).services
            raise Exceptions::NotFoundError, "Service does not exist. [#{params[:service]}]" if services.size.zero?

            task_definition_arn = services[0].task_definition
          else
            event_bridge = Aws::EventBridge::Client.new
            rules = event_bridge.list_rules(name_prefix: params[:scheduled_task_rule])
            raise Exceptions::NotFoundError, "Scheduled task rule does not exist. [#{params[:scheduled_task_rule]}]" if rules[:rules].size.zero?

            targets = event_bridge.list_targets_by_rule(rule: rules[:rules][0].name)
            target = targets.targets.find { |v| v.id == params[:scheduled_task_target] }
            raise Exceptions::NotFoundError, "Scheduled task target does not exist. [#{params[:scheduled_task_target]}]" if target.nil?

            task_definition_arn = target.ecs_parameters.task_definition_arn
          end

          ecs_client.describe_task_definition(task_definition: task_definition_arn, include: ['TAGS'])
        end

        def git_compare(params)
          task_definition = running_task_definition(params)
          build = task_definition[:tags].find { |v| v[:key] == 'genova.build' }
          text = 'Could not get diff due to some problem.'

          if build.present?
            code_manager = Genova::CodeManager::Git.new(
              params[:repository],
              branch: params[:branch],
              tag: params[:tag]
            )

            last_commit = code_manager.origin_last_commit
            deployed_commit = code_manager.find_commit(build[:value])

            if deployed_commit.present?
              if last_commit == deployed_commit
                text = 'Unchanged.'
              else
                github_client = Genova::Github::Client.new(params[:repository])
                text = github_client.build_compare_uri(deployed_commit, last_commit)
              end
            end
          end

          BlockKit::Helper.section_short_field('Git compare', text)
        end
      end
    end
  end
end
