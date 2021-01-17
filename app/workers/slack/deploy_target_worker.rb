module Slack
  class DeployTargetWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      params = session_store.params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.post_choose_target(params)
    rescue => e
      slack_notify(e, jid, id)
      raise e
    end
  end
end
