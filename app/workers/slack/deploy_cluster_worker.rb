module Slack
  class DeployClusterWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_cluster(Genova::Slack::SessionStore.new(id).params)
    rescue => e
      slack_notify(e, jid, id)
      raise e
    end
  end
end
