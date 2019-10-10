module Genova
  module Slack
    class Util
      class << self
        def history_options(slack_user_id)
          options = []

          histories = Genova::Slack::History.new(slack_user_id).list
          histories.each do |history|
            history = Oj.load(history)
            options.push(
              text: history[:id],
              value: history[:id],
              description: "#{history[:repository]} (#{history[:branch]})"
            )
          end

          options
        end

        def repository_options
          options = []

          repositories = Settings.github.repositories || []
          repositories.each do |repository|
            text = repository[:alias] || repository[:name]
            options.push(text: text, value: text)
          end

          options
        end

        def branch_options(account, repository, branch_limit = Settings.slack.interactive.branch_limit)
          code_manager = CodeManager::Git.new(account, repository)
          branches = []
          size = 0

          code_manager.origin_branches.each do |branch|
            break if size >= branch_limit

            size += 1
            branches.push(text: branch.name, value: branch.name)
          end

          branches
        end

        def cluster_options(account, repository, branch, base_path)
          clusters = []
          code_manager = CodeManager::Git.new(account, repository, branch, base_path: base_path)

          deploy_config = code_manager.load_deploy_config
          deploy_config[:clusters].each do |cluster_params|
            clusters.push(text: cluster_params[:name], value: cluster_params[:name])
          end

          clusters
        end

        def target_options(account, repository, branch, cluster, base_path)
          run_task_options = []
          service_options = []
          scheduled_task_options = []

          code_manager = CodeManager::Git.new(account, repository, branch, base_path: base_path)
          cluster_config = code_manager.load_deploy_config.cluster(cluster)

          if cluster_config[:run_tasks].present?
            cluster_config[:run_tasks].keys.each do |run_task|
              run_task_options.push(
                text: run_task,
                value: "run_task:#{run_task}"
              )
            end
          end

          if cluster_config[:services].present?
            cluster_config[:services].keys.each do |service|
              service_options.push(
                text: service,
                value: "service:#{service}"
              )
            end
          end

          if cluster_config[:scheduled_tasks].present?
            cluster_config[:scheduled_tasks].each do |rule|
              targets = rule[:targets] || {}
              targets.each do |target|
                scheduled_task_options.push(
                  text: "#{rule[:rule]}:#{target[:name]}",
                  value: "scheduled_task:#{rule[:rule]}:#{target[:name]}"
                )
              end
            end
          end

          [
            {
              text: 'Run task',
              options: run_task_options
            },
            {
              text: 'Service',
              options: service_options
            },
            {
              text: 'Scheduled task',
              options: scheduled_task_options
            }
          ]
        end
      end
    end
  end
end
