module Genova
  module Slack
    class Util
      class << self
        def history_options(slack_user_id)
          options = []

          histories = Genova::Deploy::History.new(slack_user_id).list
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

          repositories = Settings.slack.interactive.repositories || []
          repositories.each do |repository|
            split = repository.split('/')

            value = if split.size == 1
                      "#{Settings.github.account}/#{split[0]}"
                    else
                      repository.to_s
                    end

            options.push(text: repository, value: value)
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

        def service_options(account, repository, branch)
          options = []

          deploy_config = Genova::Git::LocalRepositoryManager.new(account, repository, branch).open_deploy_config
          deploy_config[:clusters].each do |cluster_params|
            cluster = cluster_params[:name]

            raise Genova::Config::DeployConfigError, 'Service is not defined.' if cluster_params[:services].nil?

            services = cluster_params[:services].keys
            services.delete(:default)

            services.each do |service|
              value = "#{cluster}:#{service}"
              options.push(text: value, value: value)
            end
          end

          options
        end
      end
    end
  end
end
