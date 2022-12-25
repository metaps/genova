module Slack
  class DeployConfirmWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :slack_deploy_confirm, retry: false

    def perform(id)
      logger.info('Started Slack::DeployConfirmWorker')

      params = Genova::Slack::SessionStore.load(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_confirm_deploy(params, show_target: false)
    rescue => e
      params.present? ? send_error(e, id, params[:user]) : send_error(e, id)
      raise e
    end
  end
end
