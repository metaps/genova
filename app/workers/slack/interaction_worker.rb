module Slack
  class InteractionWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_interaction, retry: false

    def perform(id)
      logger.info('Started Slack::InteractionWorker')

      job = Genova::Sidekiq::Queue.find(id)
      Genova::Slack::RequestHandler.handle_request(job.options)
    end
  end
end
