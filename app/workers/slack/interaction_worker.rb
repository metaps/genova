module Slack
  class InteractionWorker < BaseWorker
    sidekiq_options queue: :slack_interaction, retry: false

    def perform(id)
      logger.info('Started Slack::InteractionWorker')

      values = Genova::Sidekiq::JobStore.find(id)
      Genova::Slack::RequestHandler.handle_request(values)
    rescue => e
      slack_notify(e, jid)
      raise e
    end
  end
end
