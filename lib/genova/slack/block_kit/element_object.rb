module Genova
  module Slack
    module BlockKit
      class ElementObject
        class << self
          def repository_options
            options = []

            repositories = Settings.github.repositories || []
            repositories.each do |repository|
              text = repository[:alias] || repository[:name]
              options.push(
                text: {
                  type: 'plain_text',
                  text: text
                },
                value: text
              )
            end

            options
          end

          def history_options(params)
            options = []

            histories = Genova::Slack::Interactive::History.new(params[:user]).list
            histories.each do |history|
              data = Oj.load(history)
              time = Time.strptime(data[:id], '%Y%m%d-%H%M%S').in_time_zone(Settings.timezone).strftime('%m/%d %H:%M')

              options.push(
                text: {
                  type: 'plain_text',
                  text: time
                },
                value: data[:id],
                description: {
                  type: 'plain_text',
                  text: "#{data[:repository]}/#{data[:branch].present? ? data[:branch] : data[:tag]}/#{data[:cluster]}"
                }
              )
            end

            options
          end

          def branch_options(params)
            code_manager = Genova::CodeManager::Git.new(params[:account], params[:repository])
            options = []
            size = 0

            code_manager.origin_branches.each do |branch|
              break if size >= Settings.slack.interactive.branch_limit

              size += 1
              options.push(
                text: {
                  type: 'plain_text',
                  text: branch
                },
                value: branch
              )
            end

            options
          end

          def tag_options(params)
            code_manager = Genova::CodeManager::Git.new(params[:account], params[:repository])
            options = []
            size = 0

            code_manager.origin_tags.each do |tag|
              break if size >= Settings.slack.interactive.tag_limit

              size += 1
              options.push(
                text: {
                  type: 'plain_text',
                  text: tag
                },
                value: tag
              )
            end

            options
          end

          def cluster_options(params)
            options = []
            code_manager = Genova::CodeManager::Git.new(
              params[:account],
              params[:repository],
              branch: params[:branch],
              tag: params[:tag],
              base_path: params[:base_path]
            )

            deploy_config = code_manager.load_deploy_config
            deploy_config[:clusters].each do |cluster_params|
              next unless params[:allow_clusters].include?(cluster_params[:name])

              options.push(
                text: {
                  type: 'plain_text',
                  text: cluster_params[:name]
                },
                value: cluster_params[:name]
              )
            end

            options
          end

          def target_options(params)
            target_options = []
            code_manager = Genova::CodeManager::Git.new(
              params[:account],
              params[:repository],
              branch: params[:branch],
              tag: params[:tag],
              base_path: params[:base_path]
            )
            cluster_config = code_manager.load_deploy_config.cluster(params[:cluster])

            if cluster_config[:run_tasks].present?
              target_options << {
                label: {
                  type: 'plain_text',
                  text: 'Run task'
                },
                options: parse_run_tasks(cluster_config[:run_tasks])
              }
            end

            if cluster_config[:services].present?
              target_options << {
                label: {
                  type: 'plain_text',
                  text: 'Service'
                },
                options: parse_services(cluster_config[:services])
              }
            end

            if cluster_config[:scheduled_tasks].present?
              target_options << {
                label: {
                  type: 'plain_text',
                  text: 'Scheduled task'
                },
                options: parse_scheduled_tasks(cluster_config[:scheduled_tasks])
              }
            end

            target_options
          end

          def parse_run_tasks(run_tasks)
            options = []

            run_tasks.each_key do |run_task|
              options.push(
                text: {
                  type: 'plain_text',
                  text: run_task
                },
                value: "run_task:#{run_task}"
              )
            end

            options
          end

          def parse_services(services)
            options = []

            services.each_key do |service|
              options.push(
                text: {
                  type: 'plain_text',
                  text: service
                },
                value: "service:#{service}"
              )
            end

            options
          end

          def parse_scheduled_tasks(scheduled_tasks)
            options = []

            scheduled_tasks.each do |rule|
              targets = rule[:targets] || {}
              targets.each do |target|
                options.push(
                  text: {
                    type: 'plain_text',
                    text: "#{rule[:rule]}:#{target[:name]}"
                  },
                  value: "scheduled_task:#{rule[:rule]}:#{target[:name]}"
                )
              end
            end

            options
          end
        end
      end
    end
  end
end
