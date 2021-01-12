module Slack
  class DeployConfirmWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_confirm, retry: false

    def perform(id)
      logger.info('Started Slack::DeployConfirmWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      begin
        Genova::Slack::Bot.new.post_confirm_deploy(session_store.params)
      rescue => e
        session_store.clear
        raise e
      end
    end
  end
end
