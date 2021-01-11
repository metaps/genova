module Slack
  class InteractionWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_interaction, retry: false

    def perform(id)
      logger.info('Started Slack::InteractionWorker')

      values = Genova::Sidekiq::JobStore.find(id)
      Genova::Slack::RequestHandler.handle_request(values)
    end
  end
end
