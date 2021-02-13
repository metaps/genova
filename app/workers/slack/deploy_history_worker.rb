module Slack
  class DeployHistoryWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      params = Genova::Slack::SessionStore.load(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_confirm_deploy(params, mention: false)
    rescue => e
      params.present? ? lack_notify(e, id, params[:user]) : slack_notify(e, id)
      raise e
    end
  end
end
