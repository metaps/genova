module Slack
  class DeployClusterWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      params = Genova::Slack::SessionStore.load(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_cluster(params)
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      raise e
    end
  end
end
