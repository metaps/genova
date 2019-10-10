module Slack
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::DeployWorker')

      deploy_job = DeployJob.find(id)

      client = Genova::Client.new(deploy_job, lock_timeout: Settings.github.deploy_lock_timeout)
      bot = Genova::Slack::Bot.new

      history = Genova::Slack::History.new(deploy_job.slack_user_id)
      history.add(deploy_job)

      bot.post_detect_slack_deploy(deploy_job)
      bot.post_started_deploy(deploy_job, jid)

      client.run

      bot.post_finished_deploy(deploy_job)
    end
  end
end
