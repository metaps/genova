module Slack
  class DeployHistoryWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      params = Genova::Slack::SessionStore.new(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.post_confirm_deploy(params, true, false)
    rescue => e
      slack_notify(e, jid, id)
      raise e
    end
  end
end
