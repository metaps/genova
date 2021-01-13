module Genova
  module Slack
    class BlockKitElementObject
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

        def history_options(user)
          options = []

          histories = Genova::Slack::History.new(user).list
          histories.each do |history|
            data = Oj.load(history)
            time = Time.strptime(data[:id], '%Y%m%d-%H%M%S').strftime('%Y/%m/%d %H:%M')

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

        def branch_options(account, repository, branch_limit = Settings.slack.interactive.branch_limit)
          code_manager = Genova::CodeManager::Git.new(account, repository)
          options = []
          size = 0

          code_manager.origin_branches.each do |branch|
            break if size >= branch_limit

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

        def tag_options(account, repository, tag_limit = Settings.slack.interactive.tag_limit)
          code_manager = Genova::CodeManager::Git.new(account, repository)
          options = []
          size = 0

          code_manager.origin_tags.each do |tag|
            break if size >= tag_limit

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

        def cluster_options(account, repository, branch, tag, base_path)
          options = []
          code_manager = Genova::CodeManager::Git.new(
            account,
            repository,
            branch: branch,
            tag: tag,
            base_path: base_path
          )

          deploy_config = code_manager.load_deploy_config
          deploy_config[:clusters].each do |cluster_params|
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

        def target_options(account, repository, branch, tag, cluster, base_path)
          target_options = []
          run_tasks = []
          services = []
          scheduled_tasks = []

          code_manager = Genova::CodeManager::Git.new(account, repository, branch: branch, tag: tag, base_path: base_path)
          cluster_config = code_manager.load_deploy_config.cluster(cluster)

          if cluster_config[:run_tasks].present?
            cluster_config[:run_tasks].keys.each do |run_task|
              run_tasks.push(
                text: {
                  type: 'plain_text',
                  text: run_task
                },
                value: "run_task:#{run_task}"
              )
            end

            target_options << {
              label: {
                type: 'plain_text',
                text: 'Run task'
              },
              options: run_tasks
            }
          end

          if cluster_config[:services].present?
            cluster_config[:services].keys.each do |service|
              services.push(
                text: {
                  type: 'plain_text',
                  text: service
                },
                value: "service:#{service}"
              )
            end

            target_options << {
              label: {
                type: 'plain_text',
                text: 'Service'
              },
              options: services
            }
          end

          if cluster_config[:scheduled_tasks].present?
            cluster_config[:scheduled_tasks].each do |rule|
              targets = rule[:targets] || {}
              targets.each do |target|
                scheduled_tasks.push(
                  text: {
                    type: 'plain_text',
                    text: "#{rule[:rule]}:#{target[:name]}"
                  },
                  value: "scheduled_task:#{rule[:rule]}:#{target[:name]}"
                )
              end
            end

            target_options << {
              label: {
                type: 'plain_text',
                text: 'Scheduled task'
              },
              options: scheduled_tasks
            }
          end

          target_options
        end
      end
    end
  end
end
