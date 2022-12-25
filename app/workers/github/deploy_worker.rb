module Github
  class DeployWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :github_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployWorker')

      values = Genova::Sidekiq::JobStore.find(id)
      result = find(values[:repository], values[:branch])

      if result.nil?
        logger.info('The pushed branch does not match the conditions of "auto_deploy", so the process is terminated.')
        return
      end

      bot = Genova::Slack::Interactive::Bot.new
      response = bot.detect_auto_deploy(
        repository: values[:repository],
        branch: values[:branch],
        commit_url: values[:commit_url],
        author: values[:author]
      )

      params = {
        mode: DeployJob.mode.find_value(:auto),
        repository: values[:repository],
        branch: values[:branch]
      }

      Genova::Deploy::Step::Runner.call(result[:steps], params, Genova::Deploy::Step::SlackHook.new(response[:ts]))
    rescue => e
      send_error(e)
      raise e
    end

    private

    def find(repository, branch)
      code_manager = Genova::CodeManager::Git.new(repository, branch: branch)
      auto_deploy_config = code_manager.load_deploy_config[:auto_deploy]

      return nil if auto_deploy_config.nil?

      result = auto_deploy_config.find { |k, _v| Genova::Utils::String.pattern_match?(k[:branch], branch) }
      return nil if result.nil?

      result
    end
  end
end
