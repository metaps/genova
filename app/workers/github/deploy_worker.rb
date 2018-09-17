module Github
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployWorker')

      deploy_job = DeployJob.find(id)

      bot = Genova::Slack::Bot.new
      bot.post_detect_auto_deploy(deploy_job)
      bot.post_started_deploy(deploy_job, jid)

      client = Genova::Client.new(
        deploy_job,
        lock_timeout: Settings.github.deploy_lock_timeout
      )
      client.run

      bot.post_finished_deploy(deploy_job)
    end
  end
end
