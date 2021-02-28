module Github
  class DeployWorker < BaseWorker
    sidekiq_options queue: :github_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployWorker')

      values = Genova::Sidekiq::JobStore.find(id)

      transaction = Genova::Transaction.new(values[:repository])
      transaction.begin

      result = find(values[:account], values[:repository], values[:branch])
      return transacton.cancel if result.nil?

      bot = Genova::Slack::Interactive::Bot.new
      response = bot.detect_auto_deploy(
        account: values[:account],
        repository: values[:repository],
        branch: values[:branch],
        commit_url: values[:commit_url],
        author: values[:author],
        cluster: result[:cluster],
        services: result[:services]
      )
      deploy_bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: response[:ts])

      result[:services].each.with_index(1) do |service, i|
        deploy_job = DeployJob.create(
          id: DeployJob.generate_id,
          type: DeployJob.type.find_value(:service),
          status: DeployJob.status.find_value(:in_progress),
          mode: DeployJob.mode.find_value(:auto),
          account: values[:account],
          repository: values[:repository],
          branch: values[:branch],
          cluster: result[:cluster],
          service: service
        )

        response = deploy_bot.start_auto_deploy(deploy_job: deploy_job, index: i, total: result[:services].size)
        Genova::Run.call(deploy_job)

        deploy_bot.finished_deploy(deploy_job: deploy_job)
      end

      deploy_bot.finished_auto_deploy_all
      transaction.commit
    rescue => e
      transaction.cancel if transaction.present?
      slack_notify(e)
      raise e
    end

    private

    def find(account, repository, branch)
      code_manager = Genova::CodeManager::Git.new(account, repository, branch: branch)
      auto_deploy_config = code_manager.load_deploy_config[:auto_deploy]

      return nil if auto_deploy_config.nil?

      result = auto_deploy_config.find { |k, _v| k[:branch] == branch }
      return nil if result.nil?

      if result[:service].present?
        logger.warn('"service" parameter is deprecated. Set variable "services" instead.')

        result[:services] = [result[:service]]
        result.delete(:service)
      end

      {
        cluster: result[:cluster],
        services: result[:services]
      }
    end
  end
end
