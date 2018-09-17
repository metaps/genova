module Slack
  class DeployClusterWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      params = Genova::Sidekiq::Queue.find(id).options

      bot = Genova::Slack::Bot.new
      bot.post_choose_cluster(
        account: params[:account],
        repository: params[:repository],
        branch: params[:branch]
      )
    end
  end
end
