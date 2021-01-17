module Slack
  class DeployConfirmWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_confirm, retry: false

    def perform(id)
      logger.info('Started Slack::DeployConfirmWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_confirm_deploy(session_store.params, false)
    rescue => e
      slack_notify(e, jid, id)
      raise e
    end
  end
end
