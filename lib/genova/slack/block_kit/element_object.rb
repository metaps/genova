module Genova
  module Slack
    module BlockKit
      class ElementObject
        class << self
          def repository_options(params)
            options = []
            permission = Genova::Slack::Interactive::Permission.new(params[:user])

            repositories = Settings.github.repositories || []
            repositories.each do |repository|
              text = repository[:alias] || repository[:name]
              next unless permission.allow_repository?(text)

              options.push(
                text: {
                  type: 'plain_text',
                  text: middle_truncate(text)
                },
                value: text
              )
            end

            options
          end

          def workflow_options(params)
            options = []
            permission = Genova::Slack::Interactive::Permission.new(params[:user])

            workflows = Settings.workflows || []
            workflows.each do |workflow|
              next unless permission.allow_workflow?(workflow[:name])

              options.push(
                text: {
                  type: 'plain_text',
                  text: workflow[:name]
                },
                value: workflow[:name]
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
                  text: middle_truncate(time)
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
            code_manager = Genova::CodeManager::Git.new(params[:repository])
            options = []
            size = 0

            code_manager.origin_branches.each do |branch|
              size += 1
              options.push(
                text: {
                  type: 'plain_text',
                  text: middle_truncate(branch)
                },
                value: branch
              )
            end

            options
          end

          def tag_options(params)
            code_manager = Genova::CodeManager::Git.new(params[:repository])
            options = []
            size = 0

            code_manager.origin_tags.each do |tag|
              size += 1
              options.push(
                text: {
                  type: 'plain_text',
                  text: middle_truncate(tag)
                },
                value: tag
              )
            end

            options
          end

          def cluster_options(params)
            options = []
            permission = Genova::Slack::Interactive::Permission.new(params[:user])

            code_manager = Genova::CodeManager::Git.new(
              params[:repository],
              branch: params[:branch],
              tag: params[:tag]
            )

            deploy_config = code_manager.load_deploy_config
            deploy_config[:clusters].each do |cluster_params|
              next unless permission.allow_cluster?(cluster_params[:name])

              options.push(
                text: {
                  type: 'plain_text',
                  text: middle_truncate(cluster_params[:name])
                },
                value: cluster_params[:name]
              )
            end

            options
          end

          def run_task_options(params)
            options = []
            code_manager = Genova::CodeManager::Git.new(
              params[:repository],
              alias: params[:alias],
              branch: params[:branch],
              tag: params[:tag]
            )
            cluster_config = code_manager.load_deploy_config.find_cluster(params[:cluster])

            options = parse_run_tasks(cluster_config[:run_tasks]) if cluster_config[:run_tasks].present?

            options
          end

          def service_options(params)
            options = []
            code_manager = Genova::CodeManager::Git.new(
              params[:repository],
              alias: params[:alias],
              branch: params[:branch],
              tag: params[:tag]
            )
            cluster_config = code_manager.load_deploy_config.find_cluster(params[:cluster])

            options = parse_services(cluster_config[:services]) if cluster_config[:services].present?

            options
          end

          def scheduled_task_options(params)
            options = []
            code_manager = Genova::CodeManager::Git.new(
              params[:repository],
              alias: params[:alias],
              branch: params[:branch],
              tag: params[:tag]
            )
            cluster_config = code_manager.load_deploy_config.find_cluster(params[:cluster])

            options = parse_scheduled_tasks(cluster_config[:scheduled_tasks]) if cluster_config[:scheduled_tasks].present?

            options
          end

          private

          def parse_run_tasks(run_tasks)
            options = []

            run_tasks.each_key do |run_task|
              options.push(
                text: {
                  type: 'plain_text',
                  text: middle_truncate(run_task.to_s)
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
                  text: middle_truncate(service.to_s)
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
                    text: "#{middle_truncate(rule[:rule], 30)}:#{middle_truncate(target[:name], 30)}"
                  },
                  value: "scheduled_task:#{rule[:rule]}:#{target[:name]}"
                )
              end
            end

            options
          end

          def middle_truncate(string, length = 75)
            Strings::Truncation.truncate(string, position: :middle, omission: '...', length: length)
          end
        end
      end
    end
  end
end
