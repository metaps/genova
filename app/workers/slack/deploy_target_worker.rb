module Slack
  class DeployTargetWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      job = Genova::Sidekiq::Queue.find(id)

      bot = Genova::Slack::Bot.new
      bot.post_choose_target(
        account: job.account,
        repository: job.repository,
        branch: job.branch,
        cluster: job.cluster,
        base_path: job.base_path
      )
    end
  end
end
