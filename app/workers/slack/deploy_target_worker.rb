module Slack
  class DeployTargetWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      params = Genova::Slack::SessionStore.load(id).params
      transaction = Genova::Transaction.new(params[:repository])

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_target(params)
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      transaction.cancel if transaction.present?
      raise e
    end
  end
end
