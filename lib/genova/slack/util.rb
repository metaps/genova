module Genova
  module Slack
    class Util
      class << self
        def history_options(slack_user_id)
          options = []

          histories = Genova::Slack::History.new(slack_user_id).list
          histories.each do |history|
            history = Oj.load(history)

            text = if history[:account] == Settings.github.account
                     history[:repository]
                   else
                     "#{history[:account]}/#{history[:repository]}"
                   end

            text = "#{text} (#{history[:branch]}) - #{history[:cluster]}:#{history[:service]}"

            options.push(text: text, value: history[:id])
          end

          options
        end

        def repository_options
          options = []

          repositories = Settings.github.repositories.map { |h| h[:name] } || []
          repositories.each do |repository|
            options.push(text: repository, value: repository)
          end

          options
        end

        def branch_options(account, repository, branch_limit = Settings.slack.interactive.branch_limit)
          repository_manager = Genova::Git::LocalRepositoryManager.new(account, repository)
          branches = []
          size = 0

          repository_manager.origin_branches.each do |branch|
            break if size >= branch_limit

            size += 1
            branches.push(text: branch.name, value: branch.name)
          end

          branches
        end

        def service_option_groups(account, repository, branch)
          service_options = []

          deploy_config = Genova::Git::LocalRepositoryManager.new(account, repository, branch).load_deploy_config
          deploy_config[:clusters].each do |cluster_params|
            if cluster_params[:services].present?
              cluster = cluster_params[:name]

              services = cluster_params[:services].keys
              services.delete(:default)

              services.each do |service|
                value = "#{cluster}:#{service}"
                service_options.push(text: value, value: value)
              end
            end
          end

          [
            {
              text: 'Service',
              options: service_options
            }
          ]
        end
      end
    end
  end
end
