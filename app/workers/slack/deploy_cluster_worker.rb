module Slack
  class DeployClusterWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      params = Genova::Slack::SessionStore.load(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_cluster(params)
    rescue => e
      if params.present?
        slack_notify(e, id, params[:user])
      else
        slack_notify(e, id)
      end

      raise e
    end
  end
end
