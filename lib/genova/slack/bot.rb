module Genova
  module Slack
    class Bot
      def initialize(client = nil)
        @client = client || ::Slack::Web::Client.new(token: ENV.fetch('SLACK_API_TOKEN'))
        @channel = ENV.fetch('SLACK_CHANNEL')
        @ecs = Aws::ECS::Client.new(region: Settings.aws.region)
      end

      def post_simple_message(params)
        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: escape_emoji(params[:message])
        )
      end

      def post_choose_history(params)
        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            text: 'Command histories.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: 'post_history',
            actions: [
              {
                name: 'history',
                text: 'Pick command...',
                type: 'select',
                options: params[:options]
              },
              {
                name: 'submit',
                text: 'Cancel',
                type: 'button',
                style: 'default',
                value: 'cancel'
              }
            ]
          ]
        )
      end

      def post_choose_repository
        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            text: 'Target repository.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: 'post_repository',
            actions: [
              {
                name: 'repository',
                text: 'Pick repository...',
                type: 'select',
                options: Genova::Slack::Util.repository_options
              },
              {
                name: 'submit',
                text: 'Cancel',
                type: 'button',
                style: 'default',
                value: 'cancel'
              }
            ]
          ]
        )
      end

      def post_choose_deploy_service(params)
        query = {
          account: params[:account],
          repository: params[:repository],
          branch: params[:branch]
        }
        callback_id = Genova::Slack::CallbackIdBuilder.build('post_service', query)
        options = Genova::Slack::Util.service_options(params[:account], params[:repository], params[:branch])
        selected_options = []

        if options.size.positive?
          selected_options = [
            {
              text: options[0][:text],
              value: options[0][:value]
            }
          ]
        end

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            text: 'Target cluster and service.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            actions: [
              {
                name: 'service',
                type: 'select',
                options: options,
                selected_options: selected_options
              },
              {
                name: 'submit',
                text: 'Approve',
                type: 'button',
                style: 'primary',
                value: 'approve'
              }
            ]
          ]
        )
      end

      def post_confirm_deploy(params)
        if params[:confirm]
          message = "Repository: #{params[:account]}/#{params[:repository]}\n" \
                    "Branch: #{params[:branch]}\n" \
                    "Cluster: #{params[:cluster]}\n" \
                    "Service: #{params[:service]}"

          post_simple_message(message: message)
        end

        query = {
          account: params[:account],
          repository: params[:repository],
          branch: params[:branch],
          cluster: params[:cluster],
          service: params[:service]
        }
        callback_id = Genova::Slack::CallbackIdBuilder.build('post_deploy', query)
        compare_ids = compare_commit_ids(
          account: params[:account],
          repository: params[:repository],
          branch: params[:branch],
          cluster: params[:cluster],
          service: params[:service]
        )

        compare_text = if compare_ids[:deployed_commit_id] == compare_ids[:current_commit_id]
                         'Commit ID is unchanged.'
                       elsif compare_ids[:deployed_commit_id].nil?
                         'Deployed task does not exist.'
                       else
                         "<https://github.com/#{params[:account]}/#{params[:repository]}/" \
                         "compare/#{compare_ids[:deployed_commit_id]}...#{compare_ids[:current_commit_id]}|" \
                         "#{compare_ids[:deployed_commit_id]}...#{compare_ids[:current_commit_id]}>"
                       end

        @client.chat_postMessage(
          channel: @channel,
          response_type: 'in_channel',
          attachments: [
            text: 'Begin deployment to ECS.',
            color: Settings.slack.message.color.interactive,
            attachment_type: 'default',
            callback_id: callback_id,
            fields: [{
              title: 'Git compare',
              value: compare_text,
              short: true
            }],
            actions: [
              {
                name: 'submit',
                text: 'Approve',
                type: 'button',
                style: 'primary',
                value: 'approve'
              },
              {
                name: 'submit',
                text: 'Cancel',
                type: 'button',
                style: 'default',
                value: 'cancel'
              }
            ]
          ]
        )
      end

      def post_deploy_queue
        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          attachments: [{
            text: 'Deployment queue has been sent.',
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'Sidekiq',
              value: "#{ENV.fetch('GENOVA_URL')}/sidekiq",
              short: true
            }]
          }]
        )
      end

      def post_detect_auto_deploy(params)
        url = "https://github.com/#{params[:account]}/#{params[:repository]}/tree/#{params[:branch]}"
        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          attachments: [{
            text: 'Detected GitHub push event.',
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'Repository',
              value: "<#{url}|#{params[:account]}/#{params[:repository]}>",
              short: true
            }, {
              title: 'Branch',
              value: params[:branch],
              short: true
            }]
          }]
        )
      end

      def post_detect_slack_deploy(params)
        url = "https://github.com/#{params[:account]}/#{params[:repository]}/tree/#{params[:branch]}"
        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          attachments: [{
            text: 'Detected Slack deploy event. Retrieving repository...',
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'Repository',
              value: "<#{url}|#{params[:account]}/#{params[:repository]}>",
              short: true
            }, {
              title: 'Branch',
              value: params[:branch],
              short: true
            }, {
              title: 'Cluster',
              value: params[:cluster],
              short: true
            }, {
              title: 'Service',
              value: params[:service],
              short: true
            }]
          }]
        )
      end

      def post_started_deploy(params)
        region = Settings.aws.region
        url = "https://#{region}.console.aws.amazon.com" \
              "/ecs/home?region=#{region}#/clusters/#{params[:cluster]}/services/#{params[:service]}/tasks"

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          attachments: [{
            text: 'Deployment has started.',
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'ECS Console',
              value: url,
              short: true
            }, {
              title: 'Log',
              value: build_log_url(params[:deploy_job_id]),
              short: true
            }, {
              title: 'Sidekiq JID',
              value: params[:jid],
              short: true
            }]
          }]
        )
      end

      def post_finished_deploy(params)
        task_definition_arn = escape_emoji(params[:task_definition].task_definition_arn)

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: build_mension(params[:slack_user_id]),
          attachments: [{
            text: 'Deployment is complete.',
            color: Settings.slack.message.color.info,
            fields: [{
              title: 'DNS',
              value: elb_dns(params[:cluster], params[:service]),
              short: true
            }, {
              title: 'New task definition ARNs',
              value: task_definition_arn,
              short: true
            }]
          }]
        )
      end

      def post_error(params)
        fields = [{
          title: 'Message',
          value: escape_emoji(params[:message]),
          short: true
        }]

        if params[:deploy_job_id].present?
          fields << {
            title: 'Log',
            value: build_log_url(params[:deploy_job_id]),
            short: true
          }
        end

        @client.chat_postMessage(
          channel: @channel,
          as_user: true,
          text: build_mension(slack_user_id),
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

      def compare_commit_ids(params)
        repository_manager = Genova::Git::LocalRepositoryManager.new(params[:account], params[:repository], params[:branch])
        current_commit_id = repository_manager.origin_last_commit_id
        deploy_config = repository_manager.open_deploy_config
        deployed_commit_id = nil

        service = @ecs.describe_services(
          cluster: params[:cluster],
          services: [params[:service]]
        ).services[0]

        if service.present? && service[:status] == 'ACTIVE'
          deployed_commit_id = image_id(service[:task_definition])

        elsif deploy_config[:scheduled_tasks].present?
          rule = deploy_config[:scheduled_tasks][0][:rule]
          cloud_watch_events = Aws::CloudWatchEvents::Client.new(region: Settings.aws.region)

          begin
            task_definition_arn = cloud_watch_events.list_targets_by_rule(rule: rule).targets[0].ecs_parameters.task_definition_arn
            deployed_commit_id = image_id(task_definition_arn)
          rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException
            deployed_commit_id = nil
          end

        else
          raise TaskDefinitionNotFoundError, 'Task defintion does not exist.'
        end

        {
          current_commit_id: current_commit_id,
          deployed_commit_id: deployed_commit_id
        }
      end

      def image_id(task_definition_arn)
        container_definition = @ecs.describe_task_definition(
          task_definition: task_definition_arn
        ).task_definition.container_definitions[0]
        container_definition[:image][-40..-1]
      end

      def elb_dns(cluster, service)
        services = @ecs.describe_services(cluster: cluster, services: [service])
        load_balancer = services.dig(:services, 0, :load_balancers, 0)

        return if load_balancer.nil?

        # CLB
        if load_balancer.target_group_arn.nil?
          elb = Aws::ElasticLoadBalancing::Client.new(region: Settings.aws.region)
          lb_description = elb.describe_load_balancers(load_balancer_names: [service]).load_balancer_descriptions[0]
          dns_name = lb_description.dns_name

        # ALB
        else
          elb = Aws::ElasticLoadBalancingV2::Client.new(region: Settings.aws.region)

          target_group = elb.describe_target_groups(
            target_group_arns: [load_balancer.target_group_arn]
          ).dig(:target_groups).first
          load_balancer = elb.describe_load_balancers(
            load_balancer_arns: target_group.load_balancer_arns
          ).dig(:load_balancers).first

          dns_name = load_balancer.dns_name
        end

        dns_name
      end
    end

    class TaskDefinitionNotFoundError < Error; end
  end
end
