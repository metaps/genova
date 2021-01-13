module Slack
  class DeployHistoryWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      params = Genova::Slack::SessionStore.new(id).params

      bot = Genova::Slack::Bot.new(parent_message_ts: id)
      bot.post_confirm_deploy(params)
    end
  end
end
