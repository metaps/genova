module Slack
  class DeployHistoryWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_confirm_deploy(Genova::Slack::SessionStore.load(id).params, true, false)
    rescue => e
      slack_notify(e, id)
      raise e
    end
  end
end
