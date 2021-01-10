module Slack
  class DeployHistoryWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      params = Genova::Slack::SessionStore.new(id).params
      Genova::Slack::Bot.new.post_confirm_deploy(params)
    end
  end
end
