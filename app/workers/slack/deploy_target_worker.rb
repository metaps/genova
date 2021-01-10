module Slack
  class DeployTargetWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      params = Genova::Slack::SessionStore.new(id).params

      bot = Genova::Slack::Bot.new
      bot.post_choose_target(params)
    end
  end
end
