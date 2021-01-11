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
      end

      def post_simple_message(params)
        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: params[:text]
              }
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_choose_history(params)
        options = Genova::Slack::Util.history_options(params[:user])
        raise Genova::Exceptions::NotFoundError, 'History does not exist.' if options.size.zero?

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'plain_text',
                emoji: true,
                text: 'Please specify job to be redeployed.'
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'static_select',
                  placeholder: {
                    type: 'plain_text',
                    emoji: true,
                    text: 'Pick history...'
                  },
                  options: options,
                  action_id: 'approve_deploy_from_history'
                }
              ]
            }
          ]
        }

        @client.chat_postMessage(data)
      end

      def post_choose_repository
        options = Genova::Slack::Util.repository_options

        raise Genova::Exceptions::NotFoundError, 'Repositories is undefined.' if options.size.zero?

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'plain_text',
                text: 'Target repository.'
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'static_select',
                  placeholder: {
                    type: 'plain_text',
                    text: 'Pick repository...'
                  },
                  options: options,
                  action_id: 'approve_repository'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Cancel'
                  },
                  value: 'cancel',
                  action_id: 'cancel'
                }
              ]
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_choose_branch(params)
        options = Genova::Slack::Util.branch_options(params[:account], params[:repository])
        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'plain_text',
                text: 'Target branch.'
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'static_select',
                  placeholder: {
                    type: 'plain_text',
                    text: 'Pick branch...'
                  },
                  options: options,
                  initial_option: {
                    value: options[0][:text][:text],
                    text: {
                      type: 'plain_text',
                      text: options[0][:value]
                    }
                  },
                  action_id: 'approve_branch'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Approve'
                  },
                  value: 'approve',
                  style: 'primary',
                  action_id: 'approve_default_branch'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Cancel'
                  },
                  value: 'cancel',
                  action_id: 'cancel'
                }
              ]
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_choose_cluster(params)
        options = Genova::Slack::Util.cluster_options(params[:account], params[:repository], params[:branch], params[:base_path])
        raise Genova::Exceptions::NotFoundError, 'Clusters is undefined.' if options.size.zero?

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'plain_text',
                text: 'Target cluster.'
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'static_select',
                  placeholder: {
                    type: 'plain_text',
                    text: 'Pick cluster...'
                  },
                  options: options,
                  initial_option: {
                    value: options[0][:text][:text],
                    text: {
                      type: 'plain_text',
                      text: options[0][:value]
                    }
                  },
                  action_id: 'approve_cluster'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Approve'
                  },
                  value: 'approve',
                  style: 'primary',
                  action_id: 'approve_default_cluster'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Cancel'
                  },
                  value: 'cancel',
                  action_id: 'cancel'
                }
              ]
            }
          ]
        }

        @client.chat_postMessage(data)
      end

      def post_choose_target(params)
        option_groups = Genova::Slack::Util.target_options(
          params[:account],
          params[:repository],
          params[:branch],
          params[:cluster],
          params[:base_path]
        )
        raise Genova::Exceptions::NotFoundError, 'Target is undefined.' if option_groups.size.zero?

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'plain_text',
                text: 'Target target.'
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'static_select',
                  placeholder: {
                    type: 'plain_text',
                    text: 'Pick target...'
                  },
                  option_groups: option_groups,
                  action_id: 'approve_target'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Cancel'
                  },
                  value: 'cancel',
                  action_id: 'cancel'
                }
              ]
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_confirm_deploy(params)
        post_confirm_command(params) if params[:confirm]

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'plain_text',
                text: 'Begin deployment to ECS.'
              }
            },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: git_diff(params)
              }
            },
            {
              type: 'actions',
              elements: [
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Approve'
                  },
                  value: 'approve',
                  style: 'primary',
                  action_id: 'approve_deploy'
                },
                {
                  type: 'button',
                  text: {
                    type: 'plain_text',
                    text: 'Cancel'
                  },
                  value: 'cancel',
                  action_id: 'cancel'
                }
              ]
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_detect_auto_deploy(deploy_job)
        github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
        repository_uri = github_client.build_repository_uri
        branch_uri = github_client.build_branch_uri(deploy_job.branch)

        markdown = "*Repository*\n<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>\n" \
                   "*Branch*\n<#{branch_uri}|#{deploy_job.branch}>\n"

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'header',
              text: {
                type: 'plain_text',
                text: 'GitHub deployment was detected.'
              }
            },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: markdown
              }
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_detect_slack_deploy(deploy_job)
        github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
        repository_uri = github_client.build_repository_uri
        branch_uri = github_client.build_branch_uri(deploy_job.branch)

        fields = [
          {
            type: 'mrkdwn',
            text: "*Repository*\n<#{repository_uri}|#{deploy_job.account}/#{deploy_job.repository}>\n"
          },
          {
            type: 'mrkdwn',
            text: "*Branch*\n<#{branch_uri}|#{deploy_job.branch}>\n"
          },
          {
            type: 'mrkdwn',
            text: "*Cluster*\n#{deploy_job.cluster}\n"
          }
        ]

        if deploy_job.service.present?
          fields << {
            type: 'mrkdwn',
            text: "*Service*\n#{deploy_job.service}"
          }
        elsif deploy_job.scheduled_task_rule.present?
          fields << {
            type: 'mrkdwn',
            text: "*Scheduled task rule*\n#{deploy_job.scheduled_task_rule}\n"
          }
          fields << {
            type: 'mrkdwn',
            text: "Scheduled task target*\n#{deploy_job.scheduled_task_target}\n"
          }
        end

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'header',
              text: {
                type: 'plain_text',
                text: 'Slack deployment was detected.'
              }
            },
            {
              type: 'section',
              fields: fields
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_started_deploy(deploy_job, jid)
        url = "https://#{ENV.fetch('AWS_REGION')}.console.aws.amazon.com" \
              "/ecs/home?region=#{ENV.fetch('AWS_REGION')}#/clusters/#{deploy_job.cluster}/services/#{deploy_job.service}/tasks"

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'header',
              text: {
                type: 'plain_text',
                text: 'Deployment has started.'
              }
            },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: "*ECS Console*\n#{url}\n*Log*\n#{build_log_url(deploy_job.id)}\n*Sidekiq*\n#{jid}\n"
              }
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_finished_deploy(deploy_job)
        text = "#{build_mension(deploy_job.slack_user_id)}\n"
        text += "*New task definition ARN*\n#{escape_emoji(deploy_job.task_definition_arns.join("\n"))}\n"

        if deploy_job.tag.present?
          github_client = Genova::Github::Client.new(deploy_job.account, deploy_job.repository)
          text += "*GitHub tag*\n#{github_client.build_tag_uri(deploy_job.tag)}\n"
        end

        data = {
          channel: @channel,
          blocks: [
            {
              type: 'header',
              text: {
                type: 'plain_text',
                text: 'Deployment is complete.'
              }
            },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: text
              }
            }
          ]
        }
        @client.chat_postMessage(data)
      end

      def post_error(params)
        markdown = "*Error*\n#{params[:error].class}\n*Reason*\n#{escape_emoji(params[:error].message)}\n"

        markdown += "*Backtrace*\n```#{params[:error].backtrace.to_s.truncate(512)}```\n" if params[:error].backtrace.present?

        markdown += "*Deploy Job ID*\n#{params[:deploy_job_id]}\n" if params[:dieploy_job_id].present?

        data = {
          channel: @channel,
          blocks: [{
            type: 'header',
            text: {
              type: 'plain_text',
              text: 'Oops! Runtime error has occurred.'
            }
          }, {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: markdown
            }
          }]
        }
        @client.chat_postMessage(data)
      end

      private

      def post_confirm_command(params)
        fields = [
          {
            type: 'mrkdwn',
            text: "*Repository*\n#{params[:repository]}\n"
          },
          {
            type: 'mrkdwn',
            text: "*Branch*\n#{params[:branch]}\n"
          },
          {
            type: 'mrkdwn',
            text: "*Cluster*\n#{params[:cluster]}\n"
          }
        ]

        case params[:type]
        when DeployJob.type.find_value(:run_task)
          fields << {
            type: 'mrkdwn',
            text: "*Run task*\n#{params[:run_task]}\n"
          }

        when DeployJob.type.find_value(:service)
          fields << {
            type: 'mrkdwn',
            text: "*Service*\n#{params[:service]}\n"
          }

        when DeployJob.type.find_value(:scheduled_task)
          fields << {
            type: 'mrkdwn',
            text: "*Scheduled task rule*\n#{params[:scheduled_task_rule]}\n"
          }
          fields << {
            type: 'mrkdwn',
            value: "*Scheduled task target*\n#{params[:scheduled_task_target]}\n"
          }
        end

        data = {
          channel: @channel,
          blocks: [
            type: 'section',
            fields: fields
          ]
        }

        @client.chat_postMessage(data)
      end

      def git_diff(params)
        return 'Run task diff is not yet supported.' if params[:run_task].present?

        latest_commit_id = git_latest_commit_id(params)
        deployed_commit_id = git_deployed_commit_id(params)

        text = "*Git compare*\n"

        if latest_commit_id == deployed_commit_id
          text += "Commit ID is unchanged.\n"
        elsif deployed_commit_id.present?
          github_client = Genova::Github::Client.new(params[:account], params[:repository])
          uri = github_client.build_compare_uri(deployed_commit_id, latest_commit_id).to_s
          text += "#{uri}\n"
        else
          text += "Unknown.\n"
        end

        text
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
          branch: params[:branch]
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
