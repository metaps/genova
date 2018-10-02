module Slack
  class DeployHistoryWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy_history, retry: false

    def perform(id)
      logger.info('Started Slack::DeployHistoryWorker')

      job = Genova::Sidekiq::Queue.find(id).options
      Genova::Slack::Bot.new.post_confirm_deploy(job)
    end
  end
end
