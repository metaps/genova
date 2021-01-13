module Slack
  class DeployConfirmWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_confirm, retry: false

    def perform(id)
      logger.info('Started Slack::DeployConfirmWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      bot = Genova::Slack::Bot.new(parent_message_ts: id)
      bot.post_confirm_deploy(session_store.params, false)
    end
  end
end
