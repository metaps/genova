module Slack
  class DeployClusterWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      params = Genova::Slack::SessionStore.new(id).params

      bot = Genova::Slack::Bot.new(parent_message_ts: id)
      bot.post_choose_cluster(params)

    rescue => e
      slack_notify(e, jid, id)
      raise e
    end
  end
end
