module Slack
  class DeployClusterWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      begin
        params = Genova::Slack::SessionStore.new(id).params
        Genova::Slack::Bot.new.post_choose_cluster(params)
      rescue => e
        session_store.clear
        raise e 
      end
    end
  end
end
