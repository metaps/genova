module Slack
  class DeployConfirmWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_confirm, retry: false

    def perform(id)
      logger.info('Started Slack::DeployConfirmWorker')

      params = Genova::Slack::SessionStore.new(id).params
      Genova::Slack::Bot.new.post_confirm_deploy(params)
    end
  end
end
