module Slack
  class DeployTargetWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      params = Genova::Sidekiq::Queue.find(id).options

      bot = Genova::Slack::Bot.new
      bot.post_choose_target(
        account: params[:account],
        repository: params[:repository],
        branch: params[:branch],
        cluster: params[:cluster]
      )
    end
  end
end
