module Slack
  class DeployTargetWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_target, retry: false

    def perform(id)
      logger.info('Started Slack::DeployTargetWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      begin
        params = session_store.params
        Genova::Slack::Bot.new.post_choose_target(params)
      rescue => e
        session_store.clear
        raise e
      end
    end
  end
end
