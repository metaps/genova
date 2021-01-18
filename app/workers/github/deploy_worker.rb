module Github
  class DeployWorker < BaseWorker
    sidekiq_options queue: :github_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployDeployTargetWorker')

      values = Genova::Sidekiq::JobStore.find(id)

      deploy_target = deploy_target(values[:account], values[:repository], values[:branch])
      return if deploy_target.nil?

      deploy_job = DeployJob.create(
        id: id,
        type: DeployJob.type.find_value(:service),
        status: DeployJob.status.find_value(:in_progress),
        mode: DeployJob.mode.find_value(:auto),
        account: values[:account],
        repository: values[:repository],
        branch: values[:branch],
        cluster: deploy_target[:cluster],
        service: deploy_target[:service]
      )

      bot = Genova::Slack::Interactive::Bot.new
      bot.detect_github_event(deploy_job: deploy_job, commit_url: values[:commit_url], author: values[:author])

      client = Genova::Client.new(deploy_job)
      client.run

      bot.finished_deploy(deploy_job)
    rescue => e
      slack_notify(e, jid)
      raise e
    end

    private

    def deploy_target(account, repository, branch)
      code_manager = Genova::CodeManager::Git.new(account, repository, branch: branch)
      auto_deploy_config = code_manager.load_deploy_config[:auto_deploy]

      return nil if auto_deploy_config.nil?

      deploy_target = auto_deploy_config.find { |k, _v| k[:branch] == branch }

      return nil if deploy_target.nil?

      {
        cluster: deploy_target[:cluster],
        service: deploy_target[:service]
      }
    end
  end
end
