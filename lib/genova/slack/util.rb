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

            text = "#{text} (#{history[:branch]}) - #{history[:service]}"

            options.push(text: text,
                         value: history[:id])
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

            options.push(text: repository,
                         value: value)
          end

          options
        end

        def branch_options(account, repository, branch_limit = Settings.slack.interactive.branch_limit)
          deploy_client = Genova::Deploy::Client.new(
            Genova::Deploy::Client.mode.find_value(:slack_interactive).to_sym,
            repository,
            account: account
          )
          deploy_client.fetch_repository

          branches = []
          size = 0

          deploy_client.fetch_branches.each do |branch|
            next if branch.name.include?('>')
            break if size >= branch_limit

            size += 1
            branches.push(text: branch.name,
                          value: branch.name)
          end

          branches
        end

        def service_options(account, repository, branch)
          github = Genova::Github::Client.new(account, repository, branch)
          ecs_containers = github.fetch_deploy_config[:ecs_containers] || {}

          services = ecs_containers.keys
          services.delete(:default)

          options = []

          services.each do |service|
            options.push(text: service,
                         value: service)
          end

          options
        end
      end
    end
  end
end
