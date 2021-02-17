module Slack
  class DeployHistoryWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      params = Genova::Slack::SessionStore.load(id).params
      transaction = Genova::TransactionManager.new(params[:repository])

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_confirm_deploy(params, mention: false)
    rescue => e
      params.present? ? lack_notify(e, id, params[:user]) : slack_notify(e, id)
      transaction.cancel if transaction.present?
      raise e
    end
  end
end
