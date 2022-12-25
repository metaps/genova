module Slack
  class DeployTargetWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      params = Genova::Slack::SessionStore.load(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_target(params)
    rescue => e
      params.present? ? send(e, id, params[:user]) : send(e, id)
      raise e
    end
  end
end
