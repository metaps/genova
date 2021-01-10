module Slack
  class DeployClusterWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      params = Genova::Slack::SessionStore.new(id).params

      bot = Genova::Slack::Bot.new
      bot.post_choose_cluster(params)
    end
  end
end
