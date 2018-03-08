module CI
  module Slack
    class Util
      class << self
        def history_options(slack_user_id)
          options = []

          histories = CI::Deploy::History.new(slack_user_id).list
          histories.each do |history|
            history = Oj.load(history)

            text = if history[:account] == Settings.github.account
                     history[:repository]
                   else
                     "#{history[:account]}/#{history[:repository]}"
                   end

            text = "#{text} (#{history[:branch]}) - #{history[:environment]}"

            options.push(text: text,
                         value: history[:id])
          end

          options
        end

        def repository_options
          options = []

          repositories = ::Settings.slack.interactive.repositories
          repositories.each do |repository|
            split = repository.split('/')

            value = if split.size == 1
                      "#{::Settings.github.account}/#{split[0]}"
                    else
                      repository.to_s
                    end

            options.push(text: repository,
                         value: value)
          end

          options
        end

        def branch_options(account, repository, max_size = 20)
          deploy_client = CI::Deploy::Client.new(
            CI::Deploy::Client.mode.find_value(:slack_interactive).to_sym,
            repository,
            account: account,
            branch: nil
          )
          deploy_client.fetch_repository

          branches = []
          size = 0

          deploy_client.fetch_branches.each do |branch|
            next if branch.name.include?('>')
            break if size >= max_size

            size += 1
            branches.push(text: branch.name,
                          value: branch.name)
          end

          branches
        end

        def environment_options
          options = []

          environments = ::Settings.slack.interactive.environments
          environments.each do |environment|
            options.push(text: environment,
                         value: environment)
          end

          options
        end
      end
    end
  end
end
