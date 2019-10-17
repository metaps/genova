module Slack
  class DeployClusterWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      job = Genova::Sidekiq::Queue.find(id)

      bot = Genova::Slack::Bot.new
      bot.post_choose_cluster(
        account: job.account,
        repository: job.repository,
        branch: job.branch,
        base_path: job.base_path
      )
    end
  end
end
